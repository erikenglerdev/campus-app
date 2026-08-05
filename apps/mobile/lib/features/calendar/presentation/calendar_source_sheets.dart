// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../moodle/application/moodle_account_controller.dart';
import '../../moodle/domain/moodle_account.dart';
import '../../timetable/application/timetable_providers.dart';
import '../../timetable/data/timetable_models.dart';
import '../../timetable/presentation/timetable_group_picker_sheet.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_entry.dart';
import 'public_calendar_list.dart';

/// Opens the sheet behind one of the three source controls.
///
/// Each source gets its own sheet rather than one settings screen for all
/// three: what you can do with a source differs completely — the timetable
/// needs a course, Moodle needs an account, the events are a list of calendars
/// — and a single dialog trying to hold all of it would be a form, not a
/// control.
Future<void> showCalendarSourceSheet(
  BuildContext context,
  CalendarSource source,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => switch (source) {
      CalendarSource.timetable => const _TimetableSourceSheet(),
      CalendarSource.moodle => const _MoodleSourceSheet(),
      CalendarSource.publicCalendar => const _EventsSourceSheet(),
    },
  );
}

/// The shell every source sheet shares: a title and a scrollable body.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Show this source in the calendar" — the one control every sheet has.
class _VisibilitySwitch extends ConsumerWidget {
  const _VisibilitySwitch({required this.source});

  final CalendarSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool visible = ref
        .watch(calendarEnabledSourcesProvider)
        .contains(source);

    return SwitchListTile.adaptive(
      value: visible,
      // The state is spelled out underneath, so the switch position is never
      // the only thing carrying it.
      title: Text(l10n.calendarSourceShowInCalendar),
      subtitle: Text(
        visible ? l10n.calendarSourceVisible : l10n.calendarSourceHidden,
      ),
      secondary: Icon(visible ? Icons.visibility : Icons.visibility_off),
      onChanged: (bool _) =>
          ref.read(calendarEnabledSourcesProvider.notifier).toggle(source),
    );
  }
}

class _TimetableSourceSheet extends ConsumerWidget {
  const _TimetableSourceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? groupId = ref.watch(selectedTimetableGroupIdProvider);
    final List<TimetableGroup> groups =
        ref.watch(timetableGroupsProvider).value?.value ??
        const <TimetableGroup>[];
    final TimetableGroup? group = groupId == null
        ? null
        : groups.where((TimetableGroup g) => g.id == groupId).firstOrNull;

    return _SourceSheet(
      title: l10n.calendarSourceTimetable,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(
            // Falls back to the id only when the group list has not loaded —
            // never to an invented name.
            group?.shortName ?? groupId ?? l10n.calendarTimetableNoGroup,
          ),
          subtitle: Text(l10n.calendarTimetableGroupLabel),
        ),
        const _VisibilitySwitch(source: CalendarSource.timetable),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: OutlinedButton.icon(
            onPressed: () {
              // The picker replaces this sheet instead of stacking on it.
              Navigator.of(context).pop();
              showTimetableGroupPickerSheet(context);
            },
            icon: const Icon(Icons.search),
            label: Text(l10n.timetableGroupPickerTitle),
          ),
        ),
      ],
    );
  }
}

class _MoodleSourceSheet extends ConsumerWidget {
  const _MoodleSourceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final MoodleAccount? account = ref
        .watch(moodleAccountControllerProvider)
        .value;
    final bool connected = account != null;

    void openMoodle() {
      Navigator.of(context).pop();
      // Moodle stays a direct device integration: this opens the Moodle area
      // of the app, it does not send anything anywhere.
      GoRouter.of(context).go(AppRoutes.moodle);
    }

    return _SourceSheet(
      title: l10n.calendarSourceMoodle,
      children: <Widget>[
        if (!connected) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l10n.calendarConnectMoodleHint),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: openMoodle,
              icon: const Icon(Icons.link),
              label: Text(l10n.calendarConnectMoodle),
            ),
          ),
        ] else ...<Widget>[
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            // The account name is optional in the Moodle contract; an empty
            // "connected as …" would look broken, so the site name stands in.
            title: Text(
              l10n.moodleConnectedAs(
                account.username ?? account.siteName ?? l10n.moodleTitle,
              ),
            ),
          ),
          const _VisibilitySwitch(source: CalendarSource.moodle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: openMoodle,
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.calendarOpenMoodle),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventsSourceSheet extends ConsumerWidget {
  const _EventsSourceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return _SourceSheet(
      title: l10n.calendarSectionPublic,
      children: const <Widget>[
        _VisibilitySwitch(source: CalendarSource.publicCalendar),
        Divider(),
        // The same list the manage screen shows, writing the same selection.
        PublicCalendarList(shrinkWrap: true),
        PublicCalendarGoogleFooter(),
      ],
    );
  }
}

/// The name of a source, for the control and its sheet.
String calendarSourceLabel(AppLocalizations l10n, CalendarSource source) =>
    switch (source) {
      CalendarSource.timetable => l10n.calendarSourceTimetable,
      CalendarSource.moodle => l10n.calendarSourceMoodle,
      CalendarSource.publicCalendar => l10n.calendarSourceEvents,
    };

/// Whether [source] is loaded from a [Loaded] response at all — kept next to
/// the labels so the control and the sheet cannot disagree about a source.
IconData calendarSourceIcon(CalendarSource source) => switch (source) {
  CalendarSource.timetable => Icons.schedule_outlined,
  CalendarSource.moodle => Icons.cast_for_education_outlined,
  CalendarSource.publicCalendar => Icons.public_outlined,
};
