// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../network/json.dart';
import 'content_cache.dart';

/// `hive_ce` backed [ContentCache].
///
/// Documents are stored as JSON strings. That keeps the box free of custom
/// type adapters (no build_runner, no generated files) and makes a corrupted
/// entry a local, recoverable problem: it is dropped on read.
class HiveContentCache implements ContentCache {
  HiveContentCache(this._box);

  static const String boxName = 'campus_content_cache_v1';
  static const String _payloadKey = 'payload';
  static const String _cachedAtKey = 'cachedAt';

  final Box<String> _box;

  /// Opens the cache box. Returns a [MemoryContentCache] when Hive is not
  /// usable on this device, so the app keeps working without persistence.
  static Future<ContentCache> open() async {
    try {
      await Hive.initFlutter();
      final Box<String> box = await Hive.openBox<String>(boxName);
      return SafeContentCache(HiveContentCache(box));
    } catch (_) {
      return SafeContentCache(MemoryContentCache());
    }
  }

  @override
  Future<CacheEntry?> read(String key) async {
    final String? raw = _box.get(key);
    if (raw == null) return null;
    final Map<String, dynamic>? envelope = asJsonMap(jsonDecode(raw));
    if (envelope == null) return null;
    final Map<String, dynamic>? payload = asJsonMap(envelope[_payloadKey]);
    final DateTime? cachedAt = asDateTime(envelope[_cachedAtKey]);
    if (payload == null || cachedAt == null) return null;
    return CacheEntry(payload: payload, cachedAt: cachedAt);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    final String raw = jsonEncode(<String, dynamic>{
      _cachedAtKey: DateTime.now().toUtc().toIso8601String(),
      _payloadKey: payload,
    });
    await _box.put(key, raw);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }
}
