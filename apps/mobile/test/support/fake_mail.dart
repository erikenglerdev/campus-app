// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/mail/domain/mail_credential_store.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
import 'package:campus_koethen/features/mail/domain/mail_folder.dart';
import 'package:campus_koethen/features/mail/domain/mail_gateway.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';

/// In-memory credential store for tests. NEVER touches a real platform channel.
class InMemoryMailCredentialStore implements MailCredentialStore {
  InMemoryMailCredentialStore({this.available = true});

  /// When false, mimics a device where secure storage cannot be used.
  final bool available;
  MailCredentials? _stored;

  int writes = 0;
  int clears = 0;

  /// The most recently written credentials (synchronous peek for assertions).
  MailCredentials? get lastWritten => _stored;

  @override
  Future<MailCredentials?> read() async => _stored;

  @override
  Future<void> write(MailCredentials credentials) async {
    if (!available) {
      throw const MailFailure(MailFailureKind.secureStorageUnavailable);
    }
    _stored = credentials;
    writes++;
  }

  @override
  Future<void> clear() async {
    _stored = null;
    clears++;
  }
}

/// Scriptable fake gateway. Records calls so tests can assert no double-send etc.
class FakeMailGateway implements MailGateway {
  FakeMailGateway({
    this.verifyError,
    this.inbox = const <MailMessageHeader>[],
    this.detail,
    this.fetchInboxError,
    this.sendError,
    this.sentCopy = SentCopyResult.appended,
    this.folders = const <MailFolder>[],
    this.detailsById = const <String, MailMessageDetail>{},
    this.searchResults = const <MailMessageHeader>[],
  });

  MailFailure? verifyError;
  MailFailure? fetchInboxError;
  MailFailure? sendError;
  List<MailMessageHeader> inbox;
  MailMessageDetail? detail;
  SentCopyResult sentCopy;
  List<MailFolder> folders;

  /// Full messages returned by [fetchMessage]/[fetchMessages], keyed by id.
  Map<String, MailMessageDetail> detailsById;

  /// Headers returned by [searchMessages]. Records the last query/mailbox.
  List<MailMessageHeader> searchResults;
  String? lastSearchQuery;
  String? lastSearchMailbox;

  int verifyCalls = 0;
  int sendCalls = 0;
  int appendCalls = 0;
  bool lastIncludeAttachmentBytes = false;
  final List<String> markedSeen = <String>[];
  final List<String> fetchedMailboxes = <String>[];
  final List<OutgoingMessage> sent = <OutgoingMessage>[];
  final List<OutgoingMessage> appended = <OutgoingMessage>[];

  @override
  Future<void> verifyConnection(MailCredentials credentials) async {
    verifyCalls++;
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<List<MailFolder>> fetchMailboxes(MailCredentials credentials) async {
    return folders;
  }

  @override
  Future<List<MailMessageHeader>> fetchHeaders(
    MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    int limit = 50,
  }) async {
    fetchedMailboxes.add(mailboxPath);
    if (fetchInboxError != null) throw fetchInboxError!;
    return inbox;
  }

  @override
  Future<List<MailMessageHeader>> searchMessages(
    MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String query,
    int limit = 50,
  }) async {
    lastSearchQuery = query;
    lastSearchMailbox = mailboxPath;
    if (fetchInboxError != null) throw fetchInboxError!;
    return searchResults;
  }

  @override
  Future<MailMessageDetail> fetchMessage(
    MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String id,
    bool includeAttachmentBytes = false,
  }) async {
    lastIncludeAttachmentBytes = includeAttachmentBytes;
    final MailMessageDetail? d = detailsById[id] ?? detail;
    if (d == null) throw const MailFailure(MailFailureKind.protocol);
    return d;
  }

  @override
  Future<List<MailMessageDetail>> fetchMessages(
    MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required List<String> ids,
    bool includeAttachmentBytes = false,
  }) async {
    lastIncludeAttachmentBytes = includeAttachmentBytes;
    return ids
        .map((String id) => detailsById[id])
        .whereType<MailMessageDetail>()
        .toList();
  }

  @override
  Future<void> markSeen(
    MailCredentials credentials, {
    String mailboxPath = kInboxPath,
    required String id,
  }) async {
    markedSeen.add(id);
  }

  @override
  Future<void> send(
    MailCredentials credentials,
    OutgoingMessage message,
  ) async {
    sendCalls++;
    if (sendError != null) throw sendError!;
    sent.add(message);
  }

  @override
  Future<SentCopyResult> appendToSent(
    MailCredentials credentials,
    OutgoingMessage message,
  ) async {
    appendCalls++;
    appended.add(message);
    return sentCopy;
  }
}
