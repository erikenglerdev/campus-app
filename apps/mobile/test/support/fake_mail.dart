// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/features/mail/domain/mail_credential_store.dart';
import 'package:campus_koethen/features/mail/domain/mail_credentials.dart';
import 'package:campus_koethen/features/mail/domain/mail_failure.dart';
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
  });

  MailFailure? verifyError;
  MailFailure? fetchInboxError;
  MailFailure? sendError;
  List<MailMessageHeader> inbox;
  MailMessageDetail? detail;
  SentCopyResult sentCopy;

  int verifyCalls = 0;
  int sendCalls = 0;
  final List<String> markedSeen = <String>[];
  final List<OutgoingMessage> sent = <OutgoingMessage>[];

  @override
  Future<void> verifyConnection(MailCredentials credentials) async {
    verifyCalls++;
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<List<MailMessageHeader>> fetchInbox(
    MailCredentials credentials, {
    int limit = 50,
  }) async {
    if (fetchInboxError != null) throw fetchInboxError!;
    return inbox;
  }

  @override
  Future<MailMessageDetail> fetchMessage(
    MailCredentials credentials,
    String id,
  ) async {
    final MailMessageDetail? d = detail;
    if (d == null) throw const MailFailure(MailFailureKind.protocol);
    return d;
  }

  @override
  Future<void> markSeen(MailCredentials credentials, String id) async {
    markedSeen.add(id);
  }

  @override
  Future<SendOutcome> send(
    MailCredentials credentials,
    OutgoingMessage message,
  ) async {
    sendCalls++;
    if (sendError != null) throw sendError!;
    sent.add(message);
    return SendOutcome(sentCopy: sentCopy);
  }
}
