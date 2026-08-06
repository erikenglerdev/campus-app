// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/documents/app_document.dart';
import '../domain/case_status.dart';
import '../domain/gremio_origin.dart';
import 'requests_api_config.dart';

/// What came back from fetching one of a case's documents.
sealed class DocumentResult {
  const DocumentResult();
}

class DocumentLoaded extends DocumentResult {
  const DocumentLoaded(this.document);

  final AppDocument document;
}

/// The link did not point at the configured instance, or was not HTTPS.
///
/// Never fetched. Every one of these URLs carries the case's secret token, and
/// following one to another host is precisely how that token would leak.
class DocumentRefused extends DocumentResult {
  const DocumentRefused();
}

/// Larger than the in-app viewer can hold. Not downloaded — reading 200 MB
/// into memory to then refuse to render it helps nobody.
class DocumentTooLarge extends DocumentResult {
  const DocumentTooLarge();
}

class DocumentUnavailable extends DocumentResult {
  const DocumentUnavailable(this.reason);

  /// A short technical reason. Never the URL.
  final String reason;
}

/// Downloads a case's public documents for the in-app viewer.
///
/// Three rules hold throughout:
///
/// * **Same origin, HTTPS, no credentials.** Checked before the request and
///   again on every redirect the server proposes. A redirect to another host
///   or to `http` is refused rather than followed.
/// * **Nothing is written to disk.** The bytes go to the viewer in memory and
///   are gone when it closes; a downloaded receipt is not left lying around
///   unencrypted.
/// * **No URL is ever logged**, not in an error, not in a reason string.
class CaseDocumentDownloader {
  CaseDocumentDownloader({required Dio dio, required String baseUrl})
    : this._(dio, GremioOrigin.parse(baseUrl));

  CaseDocumentDownloader._(this._dio, this._origin);

  final Dio _dio;
  final GremioOrigin? _origin;

  /// Fetches one document of a case.
  Future<DocumentResult> fetch({
    required String url,
    required String filename,
    required String mimeType,
  }) async {
    final GremioOrigin? origin = _origin;
    if (origin == null || !origin.allows(url)) return const DocumentRefused();

    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: RequestsApiConfig.receiveTimeout,
          // Redirects are handled here rather than by dio, so each hop can be
          // checked against the allowlist instead of being followed blindly.
          followRedirects: false,
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final int status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        // A redirect could be legitimate, but we cannot verify where it leads
        // without following it. Refusing is the safe answer for a request that
        // carries a token.
        return const DocumentRefused();
      }
      if (status != 200) return DocumentUnavailable('http-$status');

      final List<int>? bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return const DocumentUnavailable('empty-body');
      }
      if (bytes.length > kMaxInMemoryPreviewBytes) {
        return const DocumentTooLarge();
      }

      return DocumentLoaded(
        AppDocument(
          filename: filename,
          mediaType: mediaTypeFor(filename, declared: mimeType),
          bytes: Uint8List.fromList(bytes),
          sizeBytes: bytes.length,
        ),
      );
    } on DioException catch (error) {
      // A type name, never the URL.
      return DocumentUnavailable('dio-${error.type.name}');
    }
  }

  /// Convenience for a document listed in a status response.
  Future<DocumentResult> fetchDocument(StatusDocument document) => fetch(
    url: document.downloadUrl,
    filename: document.filename,
    mimeType: document.mimeType,
  );
}
