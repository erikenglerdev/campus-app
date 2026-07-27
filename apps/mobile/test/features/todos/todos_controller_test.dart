// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/todos/application/todos_controller.dart';
import 'package:campus_koethen/features/todos/domain/todo.dart';
import 'package:campus_koethen/features/todos/domain/todo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryTodoStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryTodoStore();
    container = ProviderContainer(
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  Future<List<Todo>> build() => container.read(todosControllerProvider.future);
  List<Todo> current() => container.read(todosControllerProvider).requireValue;
  TodosController controller() =>
      container.read(todosControllerProvider.notifier);

  test('starts from an empty store', () async {
    expect(await build(), isEmpty);
  });

  test('reads items already persisted in the store', () async {
    await store.writeAll(<Todo>[
      Todo(id: '1', title: 'Persisted', createdAt: DateTime(2026)),
    ]);
    final List<Todo> loaded = await build();
    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Persisted');
  });

  test('add appends a trimmed, open item and persists it', () async {
    await build();
    await controller().add('  Milch kaufen  ');

    expect(current(), hasLength(1));
    expect(current().single.title, 'Milch kaufen');
    expect(current().single.done, isFalse);
    expect(await store.readAll(), hasLength(1));
  });

  test('add ignores blank or whitespace-only titles', () async {
    await build();
    await controller().add('   ');
    await controller().add('');

    expect(current(), isEmpty);
    expect(await store.readAll(), isEmpty);
  });

  test('toggle flips the done flag and persists', () async {
    await build();
    await controller().add('Aufgabe');
    final String id = current().single.id;

    await controller().toggle(id);
    expect(current().single.done, isTrue);
    expect((await store.readAll()).single.done, isTrue);

    await controller().toggle(id);
    expect(current().single.done, isFalse);
  });

  test('rename replaces the title but ignores blank input', () async {
    await build();
    await controller().add('Alt');
    final String id = current().single.id;

    await controller().rename(id, '  Neu  ');
    expect(current().single.title, 'Neu');

    await controller().rename(id, '   ');
    expect(current().single.title, 'Neu');
  });

  test('remove deletes only the matching item', () async {
    await build();
    await controller().add('A');
    await controller().add('B');
    final String firstId = current().first.id;

    await controller().remove(firstId);

    expect(current(), hasLength(1));
    expect(current().single.title, 'B');
    expect(await store.readAll(), hasLength(1));
  });

  test('clearCompleted removes done items and keeps open ones', () async {
    await build();
    await controller().add('Behalten');
    await controller().add('Erledigt');
    final String doneId = current().last.id;
    await controller().toggle(doneId);

    await controller().clearCompleted();

    expect(current(), hasLength(1));
    expect(current().single.title, 'Behalten');
    expect(await store.readAll(), hasLength(1));
  });

  test('assigns distinct ids to items added in quick succession', () async {
    await build();
    await controller().add('one');
    await controller().add('two');
    await controller().add('three');

    final Set<String> ids = current().map((Todo t) => t.id).toSet();
    expect(ids, hasLength(3));
  });
}
