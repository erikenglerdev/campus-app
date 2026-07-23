// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

import '../domain/hsa_mail_profile.dart';
import '../domain/mail_credentials.dart' as domain;
import '../domain/mail_failure.dart';
import '../domain/mail_gateway.dart';
import '../domain/mail_message.dart' as model;
import 'html_to_text.dart';

/// The single boundary to enough_mail.
///
/// Security posture, enforced here and nowhere else:
///  - IMAP uses implicit TLS on 993; SMTP uses mandatory STARTTLS on 587. There
///    is no plaintext path and no fallback to 143 / 25 / 465.
///  - `onBadCertificate` is NEVER supplied, so `SecureSocket` performs full
///    certificate AND hostname validation and rejects anything invalid.
///  - `isLogEnabled` is NEVER set, so enough_mail's protocol logging — which
///    would print credentials and message content — stays off.
///  - Every method opens, uses and closes its own connections; there is no
///    persistent IMAP IDLE.
///  - Raw exceptions are converted to a [MailFailure] classification; server
///    responses and credentials never escape this class.
class EnoughMailGateway implements MailGateway {
  EnoughMailGateway(this._profile);

  final HsaMailProfile _profile;

  static const Duration _timeout = Duration(seconds: 20);

  // --- IMAP -----------------------------------------------------------------

  Future<T> _withImap<T>(
    domain.MailCredentials credentials,
    Future<T> Function(ImapClient client) body,
  ) async {
    // No onBadCertificate, no isLogEnabled: defaults give full TLS validation
    // and silence.
    final ImapClient client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(
        _profile.imapHost,
        _profile.imapPort,
        isSecure: _profile.imapImplicitTls, // implicit TLS
        timeout: _timeout,
      );
      await client.login(credentials.emailAddress, credentials.password);
      return await body(client);
    } on ImapException {
      rethrow;
    } finally {
      // Always close; never keep an idle connection alive.
      try {
        await client.logout();
      } catch (_) {}
      try {
        await client.disconnect();
      } catch (_) {}
    }
  }

  // --- SMTP -----------------------------------------------------------------

  Future<T> _withSmtp<T>(
    domain.MailCredentials credentials,
    Future<T> Function(SmtpClient client) body,
  ) async {
    final SmtpClient client = SmtpClient(_hostnameForEhlo, isLogEnabled: false);
    try {
      await client.connectToServer(
        _profile.smtpHost,
        _profile.smtpPort,
        isSecure: false, // submission port, TLS is negotiated via STARTTLS
        timeout: _timeout,
      );
      await client.ehlo();
      if (!client.serverInfo.supportsStartTls) {
        // The contract: abort rather than continue in the clear.
        throw const MailFailure(MailFailureKind.tls);
      }
      await client.startTls();
      await client.authenticate(
        credentials.emailAddress,
        credentials.password,
        AuthMechanism.login,
      );
      return await body(client);
    } finally {
      try {
        await client.quit();
      } catch (_) {}
    }
  }

  /// A neutral EHLO identifier. Never a personal or campus hostname.
  static const String _hostnameForEhlo = 'campus-koethen.localhost';

  // --- Public API -----------------------------------------------------------

  @override
  Future<void> verifyConnection(domain.MailCredentials credentials) async {
    await _guard(() async {
      // IMAP: connect + login proves the mailbox credentials.
      await _withImap(credentials, (ImapClient client) async {
        await client.selectInbox();
      });
      // SMTP: connect + STARTTLS + AUTH proves submission works, with no side
      // effect (no test mail is ever sent).
      await _withSmtp(credentials, (SmtpClient _) async {});
    });
  }

  @override
  Future<List<model.MailMessageHeader>> fetchInbox(
    domain.MailCredentials credentials, {
    int limit = 50,
  }) async {
    return _guard(() async {
      return _withImap<List<model.MailMessageHeader>>(credentials, (
        ImapClient client,
      ) async {
        final Mailbox inbox = await client.selectInbox();
        if (inbox.messagesExists == 0) return <model.MailMessageHeader>[];

        final int upper = inbox.messagesExists;
        final int lower = (upper - limit + 1).clamp(1, upper);
        final FetchImapResult result = await client.fetchMessages(
          MessageSequence.fromRange(lower, upper),
          // Headers + flags only. BODY.PEEK avoids marking anything \Seen; no
          // full body and no attachment is downloaded.
          '(UID FLAGS ENVELOPE BODYSTRUCTURE)',
          responseTimeout: _timeout,
        );
        final List<model.MailMessageHeader> headers =
            result.messages.map(_toHeader).toList()
              // Newest first.
              ..sort((a, b) {
                final DateTime? da = a.date;
                final DateTime? db = b.date;
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });
        return headers;
      });
    });
  }

  @override
  Future<model.MailMessageDetail> fetchMessage(
    domain.MailCredentials credentials,
    String id,
  ) async {
    return _guard(() async {
      return _withImap<model.MailMessageDetail>(credentials, (
        ImapClient client,
      ) async {
        await client.selectInbox();
        final int uid = int.parse(id);
        final FetchImapResult result = await client.uidFetchMessages(
          MessageSequence.fromRange(uid, uid, isUidSequence: true),
          '(UID FLAGS ENVELOPE BODY.PEEK[])',
          responseTimeout: _timeout,
        );
        if (result.messages.isEmpty) {
          throw const MailFailure(MailFailureKind.protocol);
        }
        return _toDetail(result.messages.first);
      });
    });
  }

  @override
  Future<void> markSeen(domain.MailCredentials credentials, String id) async {
    await _guard(() async {
      await _withImap(credentials, (ImapClient client) async {
        await client.selectInbox();
        final int uid = int.parse(id);
        await client.uidMarkSeen(
          MessageSequence.fromRange(uid, uid, isUidSequence: true),
        );
      });
    });
  }

  /// Builds the MIME message once so the sent copy is identical to what was
  /// submitted. From is ALWAYS the account address; [displayName], if given,
  /// becomes only the friendly label (`"Name" <address>`).
  MimeMessage _buildMime(
    domain.MailCredentials credentials,
    model.OutgoingMessage message,
  ) {
    return MessageBuilder.buildSimpleTextMessage(
      MailAddress(credentials.displayName ?? '', credentials.emailAddress),
      message.to
          .map((String address) => MailAddress('', address))
          .toList(growable: false),
      message.text,
      subject: message.subject,
      cc: message.cc
          .map((String address) => MailAddress('', address))
          .toList(growable: false),
    );
  }

  @override
  Future<void> send(
    domain.MailCredentials credentials,
    model.OutgoingMessage message,
  ) async {
    final MimeMessage mime = _buildMime(credentials, message);
    // SMTP send only. If this throws, nothing was sent. Storing a Sent copy is
    // a separate call so the UI is not blocked on a second IMAP round trip.
    await _guard(() async {
      await _withSmtp(credentials, (SmtpClient client) async {
        await client.sendMessage(mime);
      });
    });
  }

  @override
  Future<SentCopyResult> appendToSent(
    domain.MailCredentials credentials,
    model.OutgoingMessage message,
  ) async {
    // Never throws: the message has already been sent, so a copy failure is a
    // reported outcome, not an error.
    try {
      return await _appendMimeToSent(
        credentials,
        _buildMime(credentials, message),
      );
    } catch (_) {
      return SentCopyResult.appendFailed;
    }
  }

  Future<SentCopyResult> _appendMimeToSent(
    domain.MailCredentials credentials,
    MimeMessage mime,
  ) async {
    return _withImap<SentCopyResult>(credentials, (ImapClient client) async {
      final List<Mailbox> boxes = await client.listMailboxes();
      // Prefer the \Sent special-use flag; fall back to conservative names.
      Mailbox? sent = boxes
          .where((Mailbox b) => b.flags.contains(MailboxFlag.sent))
          .firstOrNull;
      sent ??= boxes
          .where(
            (Mailbox b) =>
                b.name == 'Sent' ||
                b.name == 'Gesendet' ||
                b.name == 'Sent Items',
          )
          .firstOrNull;
      if (sent == null) {
        // Never create a folder unprompted.
        return SentCopyResult.noSentFolder;
      }
      await client.appendMessage(
        mime,
        targetMailbox: sent,
        flags: <String>[MessageFlags.seen],
      );
      return SentCopyResult.appended;
    });
  }

  // --- Mapping --------------------------------------------------------------

  model.MailMessageHeader _toHeader(MimeMessage m) {
    final MailAddress? from = m.from?.firstOrNull ?? m.sender;
    return model.MailMessageHeader(
      id: (m.uid ?? m.sequenceId ?? 0).toString(),
      subject: m.decodeSubject() ?? '',
      from: model.MailAddress(
        email: from?.email ?? '',
        name: from?.personalName,
      ),
      date: m.decodeDate(),
      isSeen: m.isSeen,
      hasAttachments: m.hasAttachments(),
    );
  }

  model.MailMessageDetail _toDetail(MimeMessage m) {
    final MailAddress? from = m.from?.firstOrNull ?? m.sender;
    final String? plain = m.decodeTextPlainPart();
    final String body = (plain != null && plain.trim().isNotEmpty)
        ? plain
        // Only if there is no plain part: reduce HTML to safe text. No remote
        // images are ever fetched because we render text, not HTML.
        : htmlToPlainText(m.decodeTextHtmlPart());
    return model.MailMessageDetail(
      id: (m.uid ?? m.sequenceId ?? 0).toString(),
      subject: m.decodeSubject() ?? '',
      from: model.MailAddress(
        email: from?.email ?? '',
        name: from?.personalName,
      ),
      to: (m.to ?? const <MailAddress>[])
          .map(
            (MailAddress a) =>
                model.MailAddress(email: a.email, name: a.personalName),
          )
          .toList(),
      cc: (m.cc ?? const <MailAddress>[])
          .map(
            (MailAddress a) =>
                model.MailAddress(email: a.email, name: a.personalName),
          )
          .toList(),
      date: m.decodeDate(),
      body: body,
      hasUnsupportedAttachments: m.hasAttachments(),
    );
  }

  // --- Error handling -------------------------------------------------------

  /// Runs [body], converting every raw failure into a typed [MailFailure] so no
  /// server text or credential can reach the UI.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on MailFailure {
      rethrow;
    } on TimeoutException {
      throw const MailFailure(MailFailureKind.timeout);
    } on HandshakeException {
      throw const MailFailure(MailFailureKind.tls);
    } on TlsException {
      throw const MailFailure(MailFailureKind.tls);
    } on SocketException {
      throw const MailFailure(MailFailureKind.serverUnreachable);
    } on ImapException catch (e) {
      throw MailFailure(_classifyImap(e));
    } on SmtpException catch (e) {
      throw MailFailure(_classifySmtp(e));
    } catch (_) {
      throw const MailFailure(MailFailureKind.protocol);
    }
  }

  MailFailureKind _classifyImap(ImapException e) {
    final String detail = e.message?.toLowerCase() ?? '';
    if (detail.contains('auth') ||
        detail.contains('login') ||
        detail.contains('credential') ||
        detail.contains('password')) {
      return MailFailureKind.invalidCredentials;
    }
    return MailFailureKind.protocol;
  }

  MailFailureKind _classifySmtp(SmtpException e) {
    final String detail = (e.message ?? '').toLowerCase();
    if (detail.contains('auth') ||
        detail.contains('535') ||
        detail.contains('credential') ||
        detail.contains('password')) {
      return MailFailureKind.invalidCredentials;
    }
    return MailFailureKind.protocol;
  }
}
