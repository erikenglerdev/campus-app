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

  /// Turns a media reference from the API into a URL that can be fetched.
  ///
  /// Editorial images are published as API-relative paths (`/v1/media/…`)
  /// rather than absolute links: the CMS address is configuration and must
  /// never travel in a payload (CLAUDE.md §2.4), and the app is forbidden from
  /// talking to the CMS at all (§2.1). Resolving happens here, once, against
  /// the very API the response came from.
  ///
  /// An absolute URL is passed through only when it is `https` — a plain-http
  /// or otherwise odd link from a response is dropped rather than loaded.
  static String? resolveMediaUrl(String? value) {
    final String path = (value ?? '').trim();
    if (path.isEmpty) return null;

    if (path.startsWith('/')) {
      return '${_stripTrailingSlash(baseUrl)}$path';
    }

    final Uri? parsed = Uri.tryParse(path);
    if (parsed == null || !parsed.isAbsolute) return null;
    return parsed.scheme == 'https' ? path : null;
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
