// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'mail_credentials.dart';
import 'mail_message.dart';

/// Outcome of trying to store a sent copy after a successful SMTP send.
enum SentCopyResult {
  /// Appended to the Sent/Gesendet folder.
  appended,

  /// The send succeeded but the copy could not be stored. The send still counts.
  appendFailed,

  /// No Sent-like folder exists and none is created unprompted.
  noSentFolder,
}

/// Result of a send: the send itself either happened or threw; if it happened,
/// [sentCopy] records what became of the Sent-folder copy.
class SendOutcome {
  const SendOutcome({required this.sentCopy});

  final SentCopyResult sentCopy;
}

/// The single boundary to enough_mail.
///
/// No enough_mail type appears in this interface, so neither the UI nor the
/// Riverpod controllers ever depend on the library. Every method opens, uses
/// and closes its own connections — there is no persistent IMAP IDLE.
abstract interface class MailGateway {
  /// Verifies BOTH the IMAP (993, implicit TLS) and SMTP (587, STARTTLS)
  /// connections and authentication. Throws [MailFailure] on any problem and
  /// never persists anything.
  Future<void> verifyConnection(MailCredentials credentials);

  /// Loads up to [limit] newest headers from INBOX. No bodies, no attachments.
  Future<List<MailMessageHeader>> fetchInbox(
    MailCredentials credentials, {
    int limit = 50,
  });

  /// Loads one message as safe plain text.
  Future<MailMessageDetail> fetchMessage(
    MailCredentials credentials,
    String id,
  );

  /// Marks a message as \Seen. Best effort — failure is non-fatal to the caller.
  Future<void> markSeen(MailCredentials credentials, String id);

  /// Sends a plain-text message via SMTP submission, then attempts to store a
  /// copy in the Sent folder. Throws [MailFailure] if the SMTP send itself
  /// fails; a failed Sent copy is reported via [SendOutcome], not thrown.
  Future<SendOutcome> send(
    MailCredentials credentials,
    OutgoingMessage message,
  );
}
