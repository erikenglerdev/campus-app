// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../l10n/l10n.dart';
import '../../../todos/application/todos_controller.dart';
import '../../../todos/domain/todo.dart';
import 'dashboard_section.dart';

/// Open local to-dos.
///
/// Entirely on-device: the to-do list never leaves the phone, so this card
/// works offline and has nothing to report to any backend.
class TasksCard extends ConsumerWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Todo>> todos = ref.watch(todosControllerProvider);

    return DashboardSection(
      title: l10n.todayTasksTitle,
      icon: Icons.checklist_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.todos),
      child: switch (todos) {
        AsyncError<List<Todo>>() => const DashboardCardError(),
        AsyncData<List<Todo>>(:final List<Todo> value) => _OpenCount(
          count: value.where((Todo t) => !t.done).length,
        ),
        // A local list loads in milliseconds; a spinner would flash more than
        // it would inform.
        _ => const _OpenCount(count: 0),
      },
    );
  }
}

class _OpenCount extends StatelessWidget {
  const _OpenCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) =>
      DashboardLine(context.l10n.todayTasksOpen(count), emphasised: count > 0);
}
