// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../domain/todo.dart';
import '../domain/todo_store.dart';

/// [TodoStore] backed by a local `hive_ce` box.
///
/// The list is user-authored data, not a cache and not a small scalar, so it
/// lives in its own Hive box (CLAUDE.md §7: SharedPreferences is only for small
/// scalars). It is NOT encrypted — a to-do list is not sensitive personal data
/// like grades or Moodle. All operations are best effort: a corrupt or
/// unavailable box degrades to "empty", never a crash.
class HiveTodoStore implements TodoStore {
  static const String _boxName = 'campus_todos_v1';
  static const String _itemsKey = 'items';

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
  Future<List<Todo>> readAll() async {
    final Box<String>? box = await _open();
    final String? raw = box?.get(_itemsKey);
    if (raw == null) return const <Todo>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <Todo>[];
      return decoded.map(Todo.fromJson).whereType<Todo>().toList();
    } catch (_) {
      return const <Todo>[];
    }
  }

  @override
  Future<void> writeAll(List<Todo> todos) async {
    final Box<String>? box = await _open();
    if (box == null) return;
    try {
      await box.put(
        _itemsKey,
        jsonEncode(todos.map((Todo t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }
}
