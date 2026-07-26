// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Configuration of the Campus API connection.
///
/// The base URL is supplied **exclusively** via
/// `--dart-define=API_BASE_URL=…`. There is no other source, no build flavour
/// file and no hard-coded production host. DEV and PROD differ by environment
/// only.
abstract final class ApiConfig {
  /// Origin of the Campus API, e.g. `https://api.example.org`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Versioned base path of all content endpoints.
  static const String basePath = '/v1';

  /// Full prefix used by the API client.
  static String get root => '${_stripTrailingSlash(baseUrl)}$basePath';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
