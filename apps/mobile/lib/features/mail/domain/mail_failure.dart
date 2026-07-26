// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Why a mail operation failed, in terms the UI can localise.
///
/// This enum is the ONLY error detail that crosses the gateway boundary. Raw
/// server responses, stack traces and — above all — credentials never do.
enum MailFailureKind {
  invalidEmail,
  invalidCredentials,
  network,
  timeout,
  tls,
  serverUnreachable,
  protocol,
  secureStorageUnavailable,
}

/// A gateway/controller error carrying only a classification.
class MailFailure implements Exception {
  const MailFailure(this.kind);

  final MailFailureKind kind;

  @override
  String toString() => 'MailFailure(${kind.name})';
}
