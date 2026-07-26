// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// The pinned HIS-QIS exam-portal endpoints of Hochschule Anhalt.
///
/// This is the single source of truth for the ONE host the grades feature is
/// allowed to talk to. Every request is validated against [allows]; anything
/// that is not HTTPS on exactly [host] is refused.
class QisProfile {
  const QisProfile();

  String get scheme => 'https';

  /// The only host credentials, cookies or the `asi` value may ever reach.
  String get host => 'service.ssc.hs-anhalt.de';

  String get baseUrl => 'https://service.ssc.hs-anhalt.de';

  /// Public entry page (also the "open in browser" target).
  String get portalUrl =>
      'https://service.ssc.hs-anhalt.de/qisserver/rds?state=user&type=0';

  /// Form-urlencoded login POST endpoint (fields `asdf` / `fdsa`).
  String get loginUrl =>
      'https://service.ssc.hs-anhalt.de/qisserver/rds'
      '?state=user&type=1&category=auth.login&startpage=portal.vm';

  /// True only for an HTTPS URL on exactly [host].
  bool allows(Uri uri) => uri.scheme == scheme && uri.host == host;
}
