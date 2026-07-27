// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/todos_controller.dart';
import '../domain/todo.dart';

/// The local to-do list at `/more/todos`.
///
/// Entirely on-device: there is no network layer and no backend behind it. The
/// list is read from and written to a local Hive box through
/// [todosControllerProvider].
class TodosScreen extends ConsumerStatefulWidget {
  const TodosScreen({super.key});

  @override
  ConsumerState<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends ConsumerState<TodosScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(todosControllerProvider.notifier).add(text);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Todo>> todos = ref.watch(todosControllerProvider);
    final bool hasCompleted =
        todos.value?.any((Todo t) => t.done) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todosTitle),
        actions: <Widget>[
          if (hasCompleted)
            IconButton(
              tooltip: l10n.todoClearCompleted,
              icon: const Icon(Icons.remove_done),
              onPressed: () =>
                  ref.read(todosControllerProvider.notifier).clearCompleted(),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _InputBar(controller: _input, focusNode: _focus, onSubmit: _submit),
          const Divider(height: AppSizes.hairline),
          Expanded(
            child: todos.when(
              loading: () => const LoadingView(),
              error: (_, _) => _EmptyTodos(l10n: l10n),
              data: (List<Todo> items) => items.isEmpty
                  ? _EmptyTodos(l10n: l10n)
                  : _TodoList(items: items),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "add a task" row pinned above the list.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.todoAddHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: l10n.todoAdd,
            icon: const Icon(Icons.add),
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

/// Empty state: no tasks yet, with a reminder that the list is local-only.
class _EmptyTodos extends StatelessWidget {
  const _EmptyTodos({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.checklist_outlined,
      title: l10n.todoEmptyTitle,
      message: l10n.todoEmptyMessage,
    );
  }
}

/// The scrollable list of to-do items.
class _TodoList extends ConsumerWidget {
  const _TodoList({required this.items});

  final List<Todo> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TodosController controller = ref.read(
      todosControllerProvider.notifier,
    );
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final Todo todo = items[index];
        return CheckboxListTile(
          key: ValueKey<String>(todo.id),
          value: todo.done,
          onChanged: (_) => controller.toggle(todo.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            todo.title,
            style: todo.done
                ? TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: colors.textSecondary,
                  )
                : null,
          ),
          secondary: IconButton(
            tooltip: l10n.todoDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.remove(todo.id),
          ),
        );
      },
    );
  }
}
