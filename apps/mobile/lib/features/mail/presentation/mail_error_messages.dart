// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import '../../../l10n/l10n.dart';
import '../domain/mail_failure.dart';

/// Maps a [MailFailure] to a localized, user-safe message.
///
/// Deliberately switches only on the typed [MailFailureKind]: raw server text,
/// exception messages and stack traces never reach the UI, so no credential or
/// protocol detail can leak into a snackbar.
String mailFailureMessage(AppLocalizations l10n, Object? error) {
  if (error is MailFailure) {
    return switch (error.kind) {
      MailFailureKind.invalidEmail => l10n.mailSetupInvalidEmail,
      MailFailureKind.invalidCredentials => l10n.mailErrorInvalidCredentials,
      MailFailureKind.network => l10n.mailErrorNetwork,
      MailFailureKind.timeout => l10n.mailErrorTimeout,
      MailFailureKind.tls => l10n.mailErrorTls,
      MailFailureKind.serverUnreachable => l10n.mailErrorServerUnreachable,
      MailFailureKind.protocol => l10n.mailErrorProtocol,
      MailFailureKind.secureStorageUnavailable => l10n.mailErrorSecureStorage,
    };
  }
  return l10n.mailErrorGeneric;
}
