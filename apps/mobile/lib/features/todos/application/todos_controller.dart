// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_todo_store.dart';
import '../domain/todo.dart';
import '../domain/todo_store.dart';

/// Local persistence port for the to-do list. Overridden in tests.
final Provider<TodoStore> todoStoreProvider = Provider<TodoStore>(
  (Ref ref) => HiveTodoStore(),
);

/// Loads and mutates the local to-do list. Every mutation updates the in-memory
/// state first (snappy UI) and then persists the whole list locally.
class TodosController extends AsyncNotifier<List<Todo>> {
  int _seq = 0;

  TodoStore get _store => ref.read(todoStoreProvider);

  @override
  Future<List<Todo>> build() => _store.readAll();

  List<Todo> get _current => state.value ?? const <Todo>[];

  Future<void> _persist(List<Todo> next) async {
    state = AsyncData<List<Todo>>(next);
    await _store.writeAll(next);
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  /// Adds a new open item at the end. Blank/whitespace-only titles are ignored.
  Future<void> add(String title) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final Todo todo = Todo(
      id: _newId(),
      title: trimmed,
      createdAt: DateTime.now(),
    );
    await _persist(<Todo>[..._current, todo]);
  }

  /// Flips the done state of the item with [id].
  Future<void> toggle(String id) async {
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.id == id) t.copyWith(done: !t.done) else t,
    ]);
  }

  /// Renames the item with [id]. Blank/whitespace-only titles are ignored.
  Future<void> rename(String id, String title) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.id == id) t.copyWith(title: trimmed) else t,
    ]);
  }

  /// Removes the item with [id].
  Future<void> remove(String id) async {
    await _persist(_current.where((Todo t) => t.id != id).toList());
  }

  /// Removes every completed item.
  Future<void> clearCompleted() async {
    await _persist(_current.where((Todo t) => !t.done).toList());
  }
}

/// Riverpod 3 auto-retries erroring providers with a backoff timer; that timer
/// outlives widget tests. Disable it — a failed local read just yields empty.
final AsyncNotifierProvider<TodosController, List<Todo>>
todosControllerProvider = AsyncNotifierProvider<TodosController, List<Todo>>(
  TodosController.new,
  retry: (_, _) => null,
);
