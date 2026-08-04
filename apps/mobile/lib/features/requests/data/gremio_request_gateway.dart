// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../domain/application_files.dart';
import '../domain/request_gateway.dart';
import '../domain/request_models.dart';
import 'requests_api_config.dart';

/// Submits a finance application straight from the device.
///
/// Direct on purpose: a submission carries the applicant's name and a copy of
/// their student card, and CLAUDE.md §2 lists this among the integrations that
/// must not pass through a Campus Köthen backend. Nothing about the request or
/// its answer is proxied, cached server-side or logged.
///
/// **The status link in the answer is a secret.** It is put into the returned
/// [SubmittedRequest] and nowhere else — never into a log line, never into a
/// failure reason.
class GremioRequestGateway implements RequestGateway {
  GremioRequestGateway({required Dio dio, required String baseUrl})
    : this._(dio, RequestsApiConfig.stripTrailingSlash(baseUrl.trim()));

  GremioRequestGateway._(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  @override
  Future<SubmissionResult> submit(RequestDraft draft) async {
    if (_baseUrl.isEmpty) return const SubmissionNotConnected();

    final SubmissionRejected? incomplete = await _checkLocally(draft);
    if (incomplete != null) return incomplete;

    final FormData form = FormData();
    form.fields.add(
      MapEntry<String, String>('locationId', '${draft.locationId}'),
    );
    form.fields.add(MapEntry<String, String>('title', draft.title.trim()));
    form.fields.add(
      MapEntry<String, String>('applicant', draft.applicant.trim()),
    );

    for (final ApplicationFileSlot slot in ApplicationFileSlot.values) {
      final RequestAttachment? file = draft.fileFor(slot);
      if (file == null) continue;
      final String? contentType = slot.contentTypeFor(file.fileName);
      form.files.add(
        MapEntry<String, MultipartFile>(
          slot.field,
          await MultipartFile.fromFile(
            file.path,
            filename: file.fileName,
            contentType: contentType == null
                ? null
                : MediaType.parse(contentType),
          ),
        ),
      );
    }

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '$_baseUrl${RequestsApiConfig.applicationsPath}',
        data: form,
        options: Options(
          headers: <String, String>{
            'Idempotency-Key': draft.idempotencyKey,
            'Accept': 'application/json',
          },
          sendTimeout: RequestsApiConfig.sendTimeout,
          receiveTimeout: RequestsApiConfig.receiveTimeout,
          // Every documented status is a result, not an exception.
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );
      return _readResponse(draft, response);
    } on DioException catch (error) {
      return _readTransportError(error);
    }
  }

  /// Refuses obviously incomplete drafts before opening a connection.
  ///
  /// Not a substitute for the server's validation — it is the authority — but
  /// sending a body that cannot succeed wastes the user's data allowance and
  /// burns a rate-limit slot for an answer we already know.
  Future<SubmissionRejected?> _checkLocally(RequestDraft draft) async {
    final List<String> issues = <String>[];
    if (draft.locationId == null) issues.add('locationId');
    if (draft.title.trim().isEmpty) issues.add('title');
    if (draft.applicant.trim().isEmpty) issues.add('applicant');

    for (final ApplicationFileSlot slot in ApplicationFileSlot.values) {
      final RequestAttachment? file = draft.fileFor(slot);
      if (file == null) {
        if (slot.isRequired) issues.add(slot.field);
        continue;
      }
      if (!slot.accepts(file.fileName)) {
        issues.add(slot.field);
        continue;
      }
      // A draft can outlive its files — cleared storage, a restored backup.
      if (!await File(file.path).exists()) issues.add(slot.field);
    }

    if (issues.isEmpty) return null;
    return SubmissionRejected(message: '', issues: issues);
  }

  SubmissionResult _readResponse(
    RequestDraft draft,
    Response<dynamic> response,
  ) {
    final int status = response.statusCode ?? 0;
    final dynamic body = response.data;
    final Map<String, dynamic> json = body is Map<String, dynamic>
        ? body
        : const <String, dynamic>{};

    if (status == 200 || status == 201) {
      final Object? statusUrl = json['statusUrl'];
      if (statusUrl is! String || statusUrl.trim().isEmpty) {
        // Without the link there is no way back to this application. Calling
        // that a success would strand it.
        return const SubmissionFailed('accepted-without-status-url');
      }
      final Object? number = json['number'];
      final Object? receipt = json['receiptPdfUrl'];
      return SubmissionAccepted(
        SubmittedRequest(
          id: draft.id,
          kind: draft.kind,
          title: draft.title.trim(),
          submittedAt: DateTime.now(),
          status: RequestStatus.submitted,
          number: number is String && number.trim().isNotEmpty ? number : null,
          trackingUrl: statusUrl,
          receiptPdfUrl: receipt is String && receipt.trim().isNotEmpty
              ? receipt
              : null,
          wasReplay:
              status == 200 ||
              response.headers.value('Idempotency-Replayed') == 'true',
        ),
      );
    }

    final Object? error = json['error'];
    final String message = error is String ? error : '';
    final List<String> issues = <String>[
      for (final Object? issue
          in json['issues'] is List
              ? json['issues'] as List<Object?>
              : const <Object?>[])
        if (issue is Map<String, dynamic> && issue['message'] is String)
          issue['message'] as String,
    ];

    return switch (status) {
      400 ||
      404 ||
      415 ||
      422 => SubmissionRejected(message: message, issues: issues),
      409 => const SubmissionConflict(),
      413 => const SubmissionTooLarge(),
      429 => SubmissionRateLimited(
        retryAfter: _retryAfter(response.headers.value('Retry-After')),
      ),
      _ => SubmissionFailed('http-$status'),
    };
  }

  static Duration? _retryAfter(String? header) {
    final int? seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  static SubmissionResult _readTransportError(DioException error) =>
      switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => const SubmissionUnreachable(),
        DioExceptionType.unknown when error.error is SocketException =>
          const SubmissionUnreachable(),
        // The reason is a type name, never the body and never a URL.
        _ => SubmissionFailed('dio-${error.type.name}'),
      };
}
