// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'todo.dart';

/// Port: local, on-device persistence for the to-do list. The whole list is
/// read and written as one unit — the list is small and this keeps the store
/// trivially correct.
abstract interface class TodoStore {
  Future<List<Todo>> readAll();
  Future<void> writeAll(List<Todo> todos);
}

/// A volatile in-memory store, used as a safe fallback and in tests.
class InMemoryTodoStore implements TodoStore {
  List<Todo> _items = const <Todo>[];

  @override
  Future<List<Todo>> readAll() async => List<Todo>.of(_items);

  @override
  Future<void> writeAll(List<Todo> todos) async =>
      _items = List<Todo>.of(todos);
}
