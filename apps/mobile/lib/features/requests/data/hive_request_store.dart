// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../domain/request_models.dart';
import '../domain/request_store.dart';

/// [RequestStore] backed by a local `hive_ce` box.
///
/// A draft can hold a long description and several attachment paths, so it is
/// not a small scalar and does not belong in SharedPreferences (CLAUDE.md §7).
///
/// Not encrypted: a draft is what the user is about to send to a student body,
/// not a credential or a grade. It may carry an e-mail address the user typed
/// themselves, which is the same category of data the local to-do list already
/// holds. Every operation is best effort — a corrupt or unavailable box
/// degrades to "no drafts", never a crash.
class HiveRequestStore implements RequestStore {
  static const String _boxName = 'campus_requests_v1';
  static const String _draftsKey = 'drafts';

  Box<String>? _box;

  Future<Box<String>?> _open() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
      return _box;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<RequestDraft>> readDrafts() async {
    final Box<String>? box = await _open();
    final String? raw = box?.get(_draftsKey);
    if (raw == null) return const <RequestDraft>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <RequestDraft>[];
      return decoded
          .map(RequestDraft.fromJson)
          .whereType<RequestDraft>()
          .toList();
    } catch (_) {
      return const <RequestDraft>[];
    }
  }

  @override
  Future<void> writeDrafts(List<RequestDraft> drafts) async {
    final Box<String>? box = await _open();
    if (box == null) return;
    try {
      await box.put(
        _draftsKey,
        jsonEncode(drafts.map((RequestDraft d) => d.toJson()).toList()),
      );
    } catch (_) {}
  }
}
