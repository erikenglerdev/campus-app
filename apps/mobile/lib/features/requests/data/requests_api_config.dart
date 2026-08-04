// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Where applications are submitted.
///
/// The origin of the student body's committee system, supplied **exclusively**
/// via `--dart-define=REQUESTS_BASE_URL=…`. There is no hard-coded host and no
/// build flavour file: DEV and PROD differ by environment only (CLAUDE.md §2).
///
/// The default is deliberately **empty**. A build that was not told where to
/// submit says so instead of guessing an address — an application sent to the
/// wrong place is worse than one that was not sent.
abstract final class RequestsApiConfig {
  static const String baseUrl = String.fromEnvironment('REQUESTS_BASE_URL');

  /// Versioned prefix of the public submission API.
  static const String basePath = '/api/public/v1';

  static const String applicationsPath = '$basePath/applications';
  static const String locationsPath = '$basePath/locations';

  static const Duration connectTimeout = Duration(seconds: 15);

  /// Generous: the body carries up to two scans of a document.
  static const Duration sendTimeout = Duration(minutes: 2);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  static String stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
