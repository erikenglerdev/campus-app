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

  /// Sends a plain-text message via SMTP submission. Throws [MailFailure] if the
  /// send fails. Deliberately does NOT touch the Sent folder: storing a copy is
  /// a separate, slower step (a second IMAP connection) that must not keep the
  /// user waiting on the compose screen after the message has already left.
  Future<void> send(MailCredentials credentials, OutgoingMessage message);

  /// Best-effort copy of an already-sent message into the Sent/Gesendet folder.
  /// Never throws: the send has already succeeded, so any problem here is
  /// reported through [SentCopyResult], not by failing.
  Future<SentCopyResult> appendToSent(
    MailCredentials credentials,
    OutgoingMessage message,
  );
}
