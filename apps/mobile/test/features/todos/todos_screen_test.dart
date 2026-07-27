// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/todos/application/todos_controller.dart';
import 'package:campus_koethen/features/todos/domain/todo.dart';
import 'package:campus_koethen/features/todos/domain/todo_store.dart';
import 'package:campus_koethen/features/todos/presentation/todos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('shows the empty state when there are no tasks', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const TodosScreen(),
      overrides: <Override>[
        todoStoreProvider.overrideWithValue(InMemoryTodoStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Keine Aufgaben'), findsOneWidget);
  });

  testWidgets('adds a task via the input field', (WidgetTester tester) async {
    final InMemoryTodoStore store = InMemoryTodoStore();
    await pumpScreen(
      tester,
      const TodosScreen(),
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Einkaufen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Einkaufen'), findsOneWidget);
    expect(find.text('Keine Aufgaben'), findsNothing);
    expect(await store.readAll(), hasLength(1));
  });

  testWidgets('toggling an item reveals the clear-completed action', (
    WidgetTester tester,
  ) async {
    final InMemoryTodoStore store = InMemoryTodoStore();
    await store.writeAll(<Todo>[
      Todo(id: '1', title: 'Aufgabe', createdAt: DateTime(2026)),
    ]);
    await pumpScreen(
      tester,
      const TodosScreen(),
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Erledigte entfernen'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Erledigte entfernen'), findsOneWidget);
    expect((await store.readAll()).single.done, isTrue);
  });

  testWidgets('deleting an item returns to the empty state', (
    WidgetTester tester,
  ) async {
    final InMemoryTodoStore store = InMemoryTodoStore();
    await store.writeAll(<Todo>[
      Todo(id: '1', title: 'Wegwerfen', createdAt: DateTime(2026)),
    ]);
    await pumpScreen(
      tester,
      const TodosScreen(),
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Wegwerfen'), findsNothing);
    expect(find.text('Keine Aufgaben'), findsOneWidget);
    expect(await store.readAll(), isEmpty);
  });

  testWidgets('clear completed removes done items only', (
    WidgetTester tester,
  ) async {
    final InMemoryTodoStore store = InMemoryTodoStore();
    await store.writeAll(<Todo>[
      Todo(id: '1', title: 'Behalten', createdAt: DateTime(2026, 1, 1)),
      Todo(
        id: '2',
        title: 'Erledigt',
        done: true,
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);
    await pumpScreen(
      tester,
      const TodosScreen(),
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Erledigte entfernen'));
    await tester.pumpAndSettle();

    expect(find.text('Erledigt'), findsNothing);
    expect(find.text('Behalten'), findsOneWidget);
  });

  testWidgets('renders English when the locale is en', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const TodosScreen(),
      locale: AppLocales.english,
      overrides: <Override>[
        todoStoreProvider.overrideWithValue(InMemoryTodoStore()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('No tasks'), findsOneWidget);
    expect(find.text('Keine Aufgaben'), findsNothing);
  });
}
