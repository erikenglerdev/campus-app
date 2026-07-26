// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'mail_message.dart';

/// Offline store for the INBOX: headers, full message bodies and (optionally)
/// attachment bytes are kept on the device so messages open instantly and work
/// without a connection.
///
/// Like the content cache, implementations **must not** throw: a cache miss or
/// a storage error degrades to "fetch online", it never crashes the app.
///
/// The store accumulates: once a message is cached it stays cached even after
/// it drops out of the newest 50 on the server, so the offline set grows over
/// time. Only removing the account [clear]s it.
abstract interface class MailCacheStore {
  /// The cached header index, newest first.
  Future<List<MailMessageHeader>> readHeaders();

  /// Replaces the header index with [headers] (the caller merges first).
  Future<void> saveHeaders(List<MailMessageHeader> headers);

  /// Ids of messages whose full body is cached.
  Future<Set<String>> cachedMessageIds();

  /// A cached full message, or null if only its header (or nothing) is known.
  Future<MailMessageDetail?> readMessage(String id);

  /// Stores a full message (and updates the known-address index from it).
  Future<void> saveMessage(MailMessageDetail message);

  /// Every address seen across cached messages (From/To/Cc), for suggestions.
  Future<List<MailAddressEntry>> knownAddresses();

  /// Wipes everything. Called when the account is removed.
  Future<void> clear();
}

/// A known correspondent for recipient suggestions.
class MailAddressEntry {
  const MailAddressEntry({required this.email, this.name});

  final String email;
  final String? name;

  /// What an autocomplete shows: `Name <email>` when a name is known.
  String get display =>
      (name != null && name!.trim().isNotEmpty) ? '$name <$email>' : email;
}

/// Collects the distinct addresses that appear on a message (From, To, Cc).
Iterable<MailAddress> addressesOf(MailMessageDetail message) sync* {
  yield message.from;
  yield* message.to;
  yield* message.cc;
}
