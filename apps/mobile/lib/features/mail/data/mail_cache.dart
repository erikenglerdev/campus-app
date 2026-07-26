// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../domain/mail_cache_store.dart';
import '../domain/mail_message.dart';
import 'mail_cache_codec.dart';

/// Merges a known correspondent into an address index, preferring an entry that
/// carries a display name. Shared by both cache implementations.
void _indexAddress(Map<String, MailAddressEntry> index, MailAddress address) {
  final String email = address.email.trim();
  if (email.isEmpty) return;
  final String key = email.toLowerCase();
  final MailAddressEntry? existing = index[key];
  final bool hasName = address.name != null && address.name!.trim().isNotEmpty;
  if (existing == null || (existing.name == null && hasName)) {
    index[key] = MailAddressEntry(
      email: email,
      name: hasName ? address.name : null,
    );
  }
}

/// In-memory [MailCacheStore]. The Hive fallback and the default for tests.
class MemoryMailCache implements MailCacheStore {
  List<MailMessageHeader> _headers = <MailMessageHeader>[];
  final Map<String, MailMessageDetail> _messages =
      <String, MailMessageDetail>{};
  final Map<String, MailAddressEntry> _addresses = <String, MailAddressEntry>{};

  @override
  Future<List<MailMessageHeader>> readHeaders() async =>
      List<MailMessageHeader>.of(_headers);

  @override
  Future<void> saveHeaders(List<MailMessageHeader> headers) async {
    _headers = List<MailMessageHeader>.of(headers);
  }

  @override
  Future<Set<String>> cachedMessageIds() async => _messages.keys.toSet();

  @override
  Future<MailMessageDetail?> readMessage(String id) async => _messages[id];

  @override
  Future<void> saveMessage(MailMessageDetail message) async {
    _messages[message.id] = message;
    for (final MailAddress a in addressesOf(message)) {
      _indexAddress(_addresses, a);
    }
  }

  @override
  Future<List<MailAddressEntry>> knownAddresses() async =>
      List<MailAddressEntry>.of(_addresses.values);

  @override
  Future<void> clear() async {
    _headers = <MailMessageHeader>[];
    _messages.clear();
    _addresses.clear();
  }
}

/// `hive_ce` backed [MailCacheStore]. Stores JSON strings so no type adapters
/// are needed and a corrupted entry is a local, recoverable miss.
class HiveMailCache implements MailCacheStore {
  HiveMailCache(this._box);

  static const String boxName = 'campus_mail_cache_v1';
  static const String _headersKey = 'headers';
  static const String _addressesKey = 'addresses';
  static const String _messagePrefix = 'msg.';

  final Box<String> _box;

  /// Opens the cache box, falling back to memory when Hive is unusable.
  static Future<MailCacheStore> open() async {
    try {
      await Hive.initFlutter();
      final Box<String> box = await Hive.openBox<String>(boxName);
      return HiveMailCache(box);
    } catch (_) {
      return MemoryMailCache();
    }
  }

  @override
  Future<List<MailMessageHeader>> readHeaders() async {
    final Object? decoded = _decode(_box.get(_headersKey));
    if (decoded is! List) return <MailMessageHeader>[];
    return decoded
        .whereType<Map>()
        .map((Map m) => MailCacheCodec.headerFrom(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<void> saveHeaders(List<MailMessageHeader> headers) async {
    await _box.put(
      _headersKey,
      jsonEncode(headers.map(MailCacheCodec.header).toList()),
    );
  }

  @override
  Future<Set<String>> cachedMessageIds() async => _box.keys
      .whereType<String>()
      .where((String k) => k.startsWith(_messagePrefix))
      .map((String k) => k.substring(_messagePrefix.length))
      .toSet();

  @override
  Future<MailMessageDetail?> readMessage(String id) async {
    final Object? decoded = _decode(_box.get('$_messagePrefix$id'));
    if (decoded is! Map) return null;
    return MailCacheCodec.detailFrom(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<void> saveMessage(MailMessageDetail message) async {
    await _box.put(
      '$_messagePrefix${message.id}',
      jsonEncode(MailCacheCodec.detail(message)),
    );
    // Merge the message's addresses into the persisted index.
    final Map<String, MailAddressEntry> index = <String, MailAddressEntry>{
      for (final MailAddressEntry e in await knownAddresses())
        e.email.toLowerCase(): e,
    };
    for (final MailAddress a in addressesOf(message)) {
      _indexAddress(index, a);
    }
    await _box.put(
      _addressesKey,
      jsonEncode(
        index.values
            .map(
              (MailAddressEntry e) => <String, dynamic>{
                'email': e.email,
                if (e.name != null) 'name': e.name,
              },
            )
            .toList(),
      ),
    );
  }

  @override
  Future<List<MailAddressEntry>> knownAddresses() async {
    final Object? decoded = _decode(_box.get(_addressesKey));
    if (decoded is! List) return <MailAddressEntry>[];
    return decoded
        .whereType<Map>()
        .map((Map m) {
          final Map<String, dynamic> j = Map<String, dynamic>.from(m);
          return MailAddressEntry(
            email: (j['email'] as String?) ?? '',
            name: j['name'] as String?,
          );
        })
        .where((MailAddressEntry e) => e.email.isNotEmpty)
        .toList();
  }

  @override
  Future<void> clear() async => _box.clear();

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
