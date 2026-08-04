// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campus_koethen/features/requests/data/gremio_request_gateway.dart';
import 'package:campus_koethen/features/requests/domain/application_files.dart';
import 'package:campus_koethen/features/requests/domain/idempotency_key.dart';
import 'package:campus_koethen/features/requests/domain/request_gateway.dart';
import 'package:campus_koethen/features/requests/domain/request_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what was sent and answers with a script.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, int status, {Map<String, String>? headers}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        for (final MapEntry<String, String> e
            in (headers ?? const <String, String>{}).entries)
          e.key: <String>[e.value],
      },
    );

late Directory _tempDir;

RequestAttachment _file(String name, {int bytes = 32}) {
  final File file = File('${_tempDir.path}/$name')
    ..writeAsBytesSync(List<int>.filled(bytes, 65));
  return RequestAttachment(fileName: name, path: file.path, sizeBytes: bytes);
}

RequestDraft _draft({
  int? locationId = 1,
  String applicant = 'A. Person',
  String title = 'Grillabend',
  Map<ApplicationFileSlot, RequestAttachment>? files,
  String? key,
}) => RequestDraft(
  id: 'draft-1',
  kind: RequestKind.financeApplication,
  createdAt: DateTime(2026, 8, 4),
  updatedAt: DateTime(2026, 8, 4),
  idempotencyKey: key ?? IdempotencyKey.generate(),
  title: title,
  applicant: applicant,
  locationId: locationId,
  files:
      files ??
      <ApplicationFileSlot, RequestAttachment>{
        ApplicationFileSlot.financeRequest: _file('antrag.pdf'),
        ApplicationFileSlot.studentCard: _file('ausweis.png'),
      },
);

GremioRequestGateway _gateway(
  _Adapter adapter, {
  String base = 'https://gremio.test',
}) {
  final Dio dio = Dio(
    BaseOptions(validateStatus: (int? s) => s != null && s < 500),
  );
  dio.httpClientAdapter = adapter;
  return GremioRequestGateway(dio: dio, baseUrl: base);
}

void main() {
  setUp(() {
    _tempDir = Directory.systemTemp.createTempSync('gremio-test');
  });
  tearDown(() {
    if (_tempDir.existsSync()) _tempDir.deleteSync(recursive: true);
  });

  group('the request that goes out', () {
    test('hits the documented path', () async {
      final _Adapter adapter = _Adapter(
        (_) => _json(<String, dynamic>{
          'statusUrl': 'https://gremio.test/status/abc',
          'receiptPdfUrl': 'https://gremio.test/status/abc/pdf',
          'number': 'A_0042_2026',
        }, 201),
      );
      await _gateway(adapter).submit(_draft());

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.uri.path, '/api/public/v1/applications');
    });

    test('carries the draft its own idempotency key', () async {
      // Not a fresh one per attempt — that is the whole mechanism.
      final _Adapter adapter = _Adapter(
        (_) => _json(<String, dynamic>{
          'statusUrl': 'https://g.test/s/a',
          'receiptPdfUrl': 'https://g.test/s/a/pdf',
          'number': null,
        }, 201),
      );
      final RequestDraft draft = _draft(
        key: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      );

      await _gateway(adapter).submit(draft);
      await _gateway(adapter).submit(draft);

      expect(
        adapter.requests
            .map((RequestOptions o) => o.headers['Idempotency-Key'])
            .toSet(),
        <String>{'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'},
      );
    });

    test('is multipart and names the fields as the API expects', () async {
      final _Adapter adapter = _Adapter(
        (_) => _json(<String, dynamic>{
          'statusUrl': 'https://g.test/s/a',
          'receiptPdfUrl': 'https://g.test/s/a/pdf',
          'number': null,
        }, 201),
      );
      await _gateway(adapter).submit(_draft());

      final RequestOptions sent = adapter.requests.single;
      expect(sent.contentType, startsWith('multipart/form-data'));
      final FormData form = sent.data as FormData;
      expect(
        form.fields.map((MapEntry<String, String> f) => f.key).toSet(),
        <String>{'locationId', 'title', 'applicant'},
      );
      expect(
        form.files.map((MapEntry<String, MultipartFile> f) => f.key).toSet(),
        <String>{'finance_request', 'student_card'},
      );
    });

    test('sends optional annexes only when present', () async {
      final _Adapter adapter = _Adapter(
        (_) => _json(<String, dynamic>{
          'statusUrl': 'https://g.test/s/a',
          'receiptPdfUrl': 'https://g.test/s/a/pdf',
          'number': null,
        }, 201),
      );
      await _gateway(adapter).submit(
        _draft(
          files: <ApplicationFileSlot, RequestAttachment>{
            ApplicationFileSlot.financeRequest: _file('antrag.pdf'),
            ApplicationFileSlot.studentCard: _file('ausweis.pdf'),
            ApplicationFileSlot.annexA: _file('anlage.pdf'),
          },
        ),
      );

      final FormData form = adapter.requests.single.data as FormData;
      expect(
        form.files.map((MapEntry<String, MultipartFile> f) => f.key).toSet(),
        <String>{'finance_request', 'student_card', 'annex_a'},
      );
    });
  });

  group('what comes back', () {
    Future<SubmissionResult> answer(
      Object? body,
      int status, {
      Map<String, String>? headers,
    }) => _gateway(
      _Adapter((_) => _json(body, status, headers: headers)),
    ).submit(_draft());

    test('201 becomes an accepted case', () async {
      final SubmissionResult result = await answer(<String, dynamic>{
        'statusUrl': 'https://gremio.test/status/abc',
        'receiptPdfUrl': 'https://gremio.test/status/abc/pdf',
        'number': 'A_0042_2026',
      }, 201);

      expect(result, isA<SubmissionAccepted>());
      final SubmittedRequest request = (result as SubmissionAccepted).request;
      expect(request.number, 'A_0042_2026');
      expect(request.trackingUrl, 'https://gremio.test/status/abc');
      expect(request.hasSafeTrackingUrl, isTrue);
      expect(request.hasSafeReceiptUrl, isTrue);
      expect(request.wasReplay, isFalse);
    });

    test('a numberless board is fine', () async {
      final SubmissionResult result = await answer(<String, dynamic>{
        'statusUrl': 'https://gremio.test/status/abc',
        'receiptPdfUrl': 'https://gremio.test/status/abc/pdf',
        'number': null,
      }, 201);
      expect((result as SubmissionAccepted).request.number, isNull);
    });

    test('200 is a replay and says so', () async {
      final SubmissionResult result = await answer(
        <String, dynamic>{
          'statusUrl': 'https://gremio.test/status/abc',
          'receiptPdfUrl': 'https://gremio.test/status/abc/pdf',
          'number': 'A_1_2026',
        },
        200,
        headers: <String, String>{'Idempotency-Replayed': 'true'},
      );
      expect((result as SubmissionAccepted).request.wasReplay, isTrue);
    });

    test('an http status link is refused, not opened', () async {
      // A link from a server is untrusted input.
      final SubmissionResult result = await answer(<String, dynamic>{
        'statusUrl': 'http://gremio.test/status/abc',
        'receiptPdfUrl': 'http://gremio.test/status/abc/pdf',
        'number': null,
      }, 201);
      expect(
        (result as SubmissionAccepted).request.hasSafeTrackingUrl,
        isFalse,
      );
    });

    test('a 201 without a status link is a failure, not a success', () async {
      // Reporting success without the only means of tracking would strand the
      // application.
      final SubmissionResult result = await answer(<String, dynamic>{
        'number': 'A_1',
      }, 201);
      expect(result, isA<SubmissionFailed>());
    });

    test('400 carries the endpoint’s own wording and field hints', () async {
      final SubmissionResult result = await answer(<String, dynamic>{
        'error': 'Bitte einen Antragsgegenstand angeben.',
        'issues': <Object?>[
          <String, dynamic>{
            'field': 'title',
            'message': 'Bitte einen Antragsgegenstand angeben.',
          },
        ],
      }, 400);

      expect(result, isA<SubmissionRejected>());
      expect(
        (result as SubmissionRejected).message,
        'Bitte einen Antragsgegenstand angeben.',
      );
      expect(result.issues, hasLength(1));
    });

    test('404, 409, 413, 429 each get their own answer', () async {
      expect(
        await answer(<String, dynamic>{'error': 'x'}, 404),
        isA<SubmissionRejected>(),
      );
      expect(
        await answer(<String, dynamic>{'error': 'x'}, 409),
        isA<SubmissionConflict>(),
      );
      expect(
        await answer(<String, dynamic>{'error': 'x'}, 413),
        isA<SubmissionTooLarge>(),
      );

      final SubmissionResult limited = await answer(
        <String, dynamic>{'error': 'x'},
        429,
        headers: <String, String>{'Retry-After': '30'},
      );
      expect(limited, isA<SubmissionRateLimited>());
      expect(
        (limited as SubmissionRateLimited).retryAfter,
        const Duration(seconds: 30),
      );
    });

    test(
      'a network error is unreachable, so the same key can be retried',
      () async {
        final SubmissionResult result = await _gateway(
          _Adapter((_) => throw const SocketException('no route')),
        ).submit(_draft());
        expect(result, isA<SubmissionUnreachable>());
      },
    );

    test('an unconfigured build never pretends', () async {
      final SubmissionResult result = await _gateway(
        _Adapter((_) => _json(<String, dynamic>{}, 201)),
        base: '',
      ).submit(_draft());
      expect(result, isA<SubmissionNotConnected>());
    });
  });

  group('refusing to send an incomplete draft', () {
    Future<SubmissionResult> attempt(RequestDraft draft) async {
      final _Adapter adapter = _Adapter((_) => _json(<String, dynamic>{}, 201));
      final SubmissionResult result = await _gateway(adapter).submit(draft);
      expect(
        adapter.requests,
        isEmpty,
        reason: 'nothing should have been sent',
      );
      return result;
    }

    test('without a location', () async {
      expect(
        await attempt(_draft(locationId: null)),
        isA<SubmissionRejected>(),
      );
    });

    test('without an applicant', () async {
      expect(await attempt(_draft(applicant: '  ')), isA<SubmissionRejected>());
    });

    test('without a title', () async {
      expect(await attempt(_draft(title: '')), isA<SubmissionRejected>());
    });

    test('without the mandatory files', () async {
      expect(
        await attempt(
          _draft(files: const <ApplicationFileSlot, RequestAttachment>{}),
        ),
        isA<SubmissionRejected>(),
      );
    });

    test('with a file that has gone missing from disk', () async {
      // A draft can outlive its files: the user cleared storage, or restored a
      // backup. Better a clear refusal than a half-empty multipart body.
      final RequestDraft draft = _draft(
        files: <ApplicationFileSlot, RequestAttachment>{
          ApplicationFileSlot.financeRequest: const RequestAttachment(
            fileName: 'weg.pdf',
            path: '/nirgendwo/weg.pdf',
          ),
          ApplicationFileSlot.studentCard: _file('ausweis.pdf'),
        },
      );
      expect(await attempt(draft), isA<SubmissionRejected>());
    });

    test('with a file the slot does not accept', () async {
      final RequestDraft draft = _draft(
        files: <ApplicationFileSlot, RequestAttachment>{
          ApplicationFileSlot.financeRequest: _file('antrag.png'),
          ApplicationFileSlot.studentCard: _file('ausweis.pdf'),
        },
      );
      expect(await attempt(draft), isA<SubmissionRejected>());
    });
  });
}
