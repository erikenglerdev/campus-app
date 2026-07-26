// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';

import '../domain/hsa_mail_profile.dart';
import '../domain/mail_credentials.dart' as domain;
import '../domain/mail_failure.dart';
import '../domain/mail_folder.dart';
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

  /// Selects [mailboxPath], taking the cheap INBOX shortcut when possible.
  Future<void> _select(ImapClient client, String mailboxPath) async {
    if (mailboxPath == kInboxPath) {
      await client.selectInbox();
    } else {
      await client.selectMailboxByPath(mailboxPath);
    }
  }

  // --- Public API -----------------------------------------------------------

  @override
  Future<List<MailFolder>> fetchMailboxes(
    domain.MailCredentials credentials,
  ) async {
    return _guard(() async {
      return _withImap<List<MailFolder>>(credentials, (
        ImapClient client,
      ) async {
        final List<Mailbox> boxes = await client.listMailboxes(recursive: true);
        return boxes.map(_toFolder).toList();
      });
    });
  }

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
  Future<List<model.MailMessageHeader>> fetchHeaders(
    domain.MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    int limit = 50,
  }) async {
    return _guard(() async {
      return _withImap<List<model.MailMessageHeader>>(credentials, (
        ImapClient client,
      ) async {
        final Mailbox inbox = mailboxPath == kInboxPath
            ? await client.selectInbox()
            : await client.selectMailboxByPath(mailboxPath);
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
        return result.messages.map(_toHeader).toList()..sort(_newestFirst);
      });
    });
  }

  @override
  Future<List<model.MailMessageHeader>> searchMessages(
    domain.MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String query,
    int limit = 50,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const <model.MailMessageHeader>[];
    return _guard(() async {
      return _withImap<List<model.MailMessageHeader>>(credentials, (
        ImapClient client,
      ) async {
        await _select(client, mailboxPath);
        // IMAP quoted-string escaping; TEXT matches the whole message (headers,
        // so the sender, AND the body, so the content). CHARSET UTF-8 lets
        // umlauts match.
        final String safe = trimmed
            .replaceAll('\\', r'\\')
            .replaceAll('"', r'\"');
        final SearchImapResult result = await client.uidSearchMessages(
          searchCriteria: 'CHARSET UTF-8 TEXT "$safe"',
          responseTimeout: _timeout,
        );
        final MessageSequence? matches = result.matchingSequence;
        if (matches == null || matches.isEmpty) {
          return <model.MailMessageHeader>[];
        }
        // Fetch only the newest [limit] matches to bound the work.
        final List<int> uids = matches.toList()..sort();
        final List<int> newest = uids.reversed.take(limit).toList();
        final FetchImapResult fetched = await client.uidFetchMessages(
          MessageSequence.fromIds(newest, isUid: true),
          '(UID FLAGS ENVELOPE BODYSTRUCTURE)',
          responseTimeout: _timeout,
        );
        return fetched.messages.map(_toHeader).toList()..sort(_newestFirst);
      });
    });
  }

  @override
  Future<model.MailMessageDetail> fetchMessage(
    domain.MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String id,
    bool includeAttachmentBytes = false,
  }) async {
    return _guard(() async {
      return _withImap<model.MailMessageDetail>(credentials, (
        ImapClient client,
      ) async {
        await _select(client, mailboxPath);
        final int uid = int.parse(id);
        final FetchImapResult result = await client.uidFetchMessages(
          MessageSequence.fromRange(uid, uid, isUidSequence: true),
          '(UID FLAGS ENVELOPE BODY.PEEK[])',
          responseTimeout: _timeout,
        );
        if (result.messages.isEmpty) {
          throw const MailFailure(MailFailureKind.protocol);
        }
        return _toDetail(result.messages.first, includeAttachmentBytes);
      });
    });
  }

  @override
  Future<List<model.MailMessageDetail>> fetchMessages(
    domain.MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required List<String> ids,
    bool includeAttachmentBytes = false,
  }) async {
    if (ids.isEmpty) return const <model.MailMessageDetail>[];
    return _guard(() async {
      return _withImap<List<model.MailMessageDetail>>(credentials, (
        ImapClient client,
      ) async {
        await _select(client, mailboxPath);
        final List<int> uids = ids
            .map(int.tryParse)
            .whereType<int>()
            .toList(growable: false);
        final List<model.MailMessageDetail> details =
            <model.MailMessageDetail>[];
        // One session, one fetch per id: enough_mail returns whole messages per
        // UID; a tighter batch API is not worth the risk of partial parsing.
        for (final int uid in uids) {
          final FetchImapResult result = await client.uidFetchMessages(
            MessageSequence.fromRange(uid, uid, isUidSequence: true),
            '(UID FLAGS ENVELOPE BODY.PEEK[])',
            responseTimeout: _timeout,
          );
          if (result.messages.isNotEmpty) {
            details.add(
              _toDetail(result.messages.first, includeAttachmentBytes),
            );
          }
        }
        return details;
      });
    });
  }

  @override
  Future<void> markSeen(
    domain.MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String id,
  }) async {
    await _guard(() async {
      await _withImap(credentials, (ImapClient client) async {
        await _select(client, mailboxPath);
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

  /// Sorts headers newest first; messages without a date sink to the end.
  static int _newestFirst(
    model.MailMessageHeader a,
    model.MailMessageHeader b,
  ) {
    final DateTime? da = a.date;
    final DateTime? db = b.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

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

  model.MailMessageDetail _toDetail(
    MimeMessage m,
    bool includeAttachmentBytes,
  ) {
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
      attachments: _attachmentsOf(m, includeAttachmentBytes),
    );
  }

  /// Extracts attachment metadata. Bytes are decoded from the already downloaded
  /// message (no extra fetch, no network, no file written): images always (for
  /// the inline preview) and — when [includeFiles] — other types too, so a
  /// downloaded attachment is available offline.
  List<model.MailAttachment> _attachmentsOf(MimeMessage m, bool includeFiles) {
    final List<ContentInfo> infos = m.findContentInfo();
    return infos.map((ContentInfo info) {
      final String type = info.mediaType?.text ?? 'application/octet-stream';
      final Uint8List? bytes = (info.isImage || includeFiles)
          ? m.getPart(info.fetchId)?.decodeContentBinary()
          : null;
      return model.MailAttachment(
        filename: info.fileName ?? info.fetchId,
        mediaType: type,
        sizeBytes: info.size ?? bytes?.length,
        bytes: bytes,
      );
    }).toList();
  }

  MailFolder _toFolder(Mailbox box) => MailFolder(
    path: box.encodedPath,
    name: box.name,
    role: _roleOf(box),
    isSelectable: !box.isNotSelectable,
  );

  MailFolderRole _roleOf(Mailbox box) {
    if (box.isInbox) return MailFolderRole.inbox;
    if (box.isSent) return MailFolderRole.sent;
    if (box.isDrafts) return MailFolderRole.drafts;
    if (box.isTrash) return MailFolderRole.trash;
    if (box.isJunk) return MailFolderRole.junk;
    if (box.isArchive) return MailFolderRole.archive;
    return MailFolderRole.plain;
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
