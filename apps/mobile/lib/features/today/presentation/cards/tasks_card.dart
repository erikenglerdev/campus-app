// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../l10n/l10n.dart';
import '../../../moodle/application/moodle_account_controller.dart';
import '../../../moodle/application/moodle_controller.dart';
import '../../../moodle/domain/moodle_deadline.dart';
import '../../../todos/application/todos_controller.dart';
import '../../../todos/domain/todo.dart';
import 'dashboard_section.dart';

/// Open local to-dos, plus upcoming Moodle submissions once Moodle is set up.
///
/// The to-do list is entirely on-device. The Moodle part is read straight from
/// Moodle by the device and, like everything else about that integration,
/// never touches a Campus Köthen backend. Only the **number** of upcoming
/// submissions appears here — a deadline's title can name a course and an
/// assignment, which is more than a dashboard should reveal at a glance.
class TasksCard extends ConsumerWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Todo>> todos = ref.watch(todosControllerProvider);

    // Only when the user actually connected Moodle.
    final bool moodleConnected =
        ref.watch(moodleAccountControllerProvider).value != null;
    final MoodleOverviewState? moodle = moodleConnected
        ? ref.watch(moodleControllerProvider).value
        : null;
    final DateTime now = DateTime.now();
    final DateTime horizon = now.add(const Duration(days: 7));
    final int dueSoon =
        moodle?.deadlines
            .where(
              (MoodleDeadline d) =>
                  d.dueAt.isAfter(now) && d.dueAt.isBefore(horizon),
            )
            .length ??
        0;

    return DashboardSection(
      title: l10n.todayTasksTitle,
      icon: Icons.checklist_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.todos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          switch (todos) {
            AsyncError<List<Todo>>() => const DashboardCardError(),
            AsyncData<List<Todo>>(:final List<Todo> value) => _OpenCount(
              count: value.where((Todo t) => !t.done).length,
            ),
            // A local list loads in milliseconds; a spinner would flash more
            // than it would inform.
            _ => const _OpenCount(count: 0),
          },
          if (dueSoon > 0) ...<Widget>[
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Icon(
                  Icons.assignment_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.todayTasksMoodleDue(dueSoon),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
