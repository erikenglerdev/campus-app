// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../../moodle/application/moodle_account_controller.dart';
import '../../moodle/application/moodle_controller.dart';
import '../../timetable/application/timetable_week.dart';
import '../../timetable/presentation/timetable_group_picker_sheet.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_entry.dart';
import 'calendar_source_sheets.dart';
import 'week_grid_view.dart';
import 'week_strip.dart';

/// The top-level "Kalender" tab: one calendar merged from the timetable and
/// Moodle deadlines, with an explicit month-grid vs list toggle.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    // Populate Moodle deadlines lazily on open (respects the 24-hour gate).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(moodleAccountControllerProvider).value != null) {
        ref.read(moodleControllerProvider.notifier).maybeAutoSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CalendarViewMode mode = ref.watch(calendarViewModeProvider);
    final CalendarData data = ref.watch(focusedCalendarDataProvider);

    // No app bar: the screen starts with what it is for. A title saying
    // "Kalender" above a calendar, next to a row of icons whose meaning had to
    // be guessed, was a row of a phone's height spent on nothing.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // View selection and source controls stay put; everything else
            // scrolls with the view, so nothing can overflow a short viewport.
            _ViewToggle(mode: mode),
            _SourceControls(data: data),
            Expanded(
              child: switch (mode) {
                CalendarViewMode.day => _DayAgendaView(data: data),
                CalendarViewMode.week => _WeekView(data: data),
                CalendarViewMode.list => _ListView(data: data),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrollable header shared by all views: per-source error banners and
/// (when needed) the "pick a course" hint.
///
/// One source failing never removes the others — the banner says which one is
/// missing and the rest of the calendar keeps its data.
List<Widget> _calendarHeader(BuildContext context, CalendarData data) {
  final AppLocalizations l10n = context.l10n;
  Widget banner(String message) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      0,
    ),
    child: StatusBanner(
      tone: StatusTone.warning,
      icon: Icons.sync_problem,
      title: message,
      message: '',
    ),
  );
  return <Widget>[
    if (data.hasTimetableError) banner(l10n.calendarTimetableUnavailable),
    if (data.hasMoodleError) banner(l10n.calendarMoodleUnavailable),
    if (data.needsGroup) _GroupHint(),
  ];
}

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.mode});

  final CalendarViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    // Icon *and* label do not fit two segments onto a 320 px phone once the
    // user scales text up. The label is what gets dropped, never the control:
    // the icon keeps its tooltip and its accessible name, so nothing is lost
    // for a screen reader.
    final bool roomForLabels =
        MediaQuery.textScalerOf(context).scale(14) < 20 ||
        MediaQuery.sizeOf(context).width > 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: SegmentedButton<CalendarViewMode>(
        segments: <ButtonSegment<CalendarViewMode>>[
          ButtonSegment<CalendarViewMode>(
            value: CalendarViewMode.day,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n.calendarViewDay,
            label: roomForLabels ? Text(l10n.calendarViewDay) : null,
          ),
          ButtonSegment<CalendarViewMode>(
            value: CalendarViewMode.week,
            icon: const Icon(Icons.grid_on_outlined),
            tooltip: l10n.calendarViewWeek,
            label: roomForLabels ? Text(l10n.calendarViewWeek) : null,
          ),
          ButtonSegment<CalendarViewMode>(
            value: CalendarViewMode.list,
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: l10n.calendarViewList,
            label: roomForLabels ? Text(l10n.calendarViewList) : null,
          ),
        ],
        selected: <CalendarViewMode>{mode},
        onSelectionChanged: (Set<CalendarViewMode> selection) =>
            ref.read(calendarViewModeProvider.notifier).set(selection.first),
      ),
    );
  }
}

/// The three sources, each a button that opens its own sheet.
///
/// Not toggles: what a source needs differs — the timetable needs a course,
/// Moodle needs an account, the events are a list of calendars — so tapping
/// opens the place where all of that lives. The state is on the button itself
/// in words, an icon **and** the accessible state, never in a colour.
class _SourceControls extends ConsumerWidget {
  const _SourceControls({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    String stateOf(CalendarSource source) {
      if (source == CalendarSource.moodle && !data.moodleConnected) {
        return l10n.calendarSourceNotConnected;
      }
      return data.enabledSources.contains(source)
          ? l10n.calendarSourceVisible
          : l10n.calendarSourceHidden;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      // A Wrap, not a Row: three labels plus their state do not share one line
      // on a narrow phone at a large text size, and a button that has to
      // truncate its own state is worse than one on the next line.
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          for (final CalendarSource source in CalendarSource.values)
            _SourceButton(
              icon: calendarSourceIcon(source),
              label: calendarSourceLabel(l10n, source),
              state: stateOf(source),
              active:
                  data.enabledSources.contains(source) &&
                  (source != CalendarSource.moodle || data.moodleConnected),
              onPressed: () => showCalendarSourceSheet(context, source),
            ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.state,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String state;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      // Announced as "Stundenplan, Sichtbar" — the state is part of the name,
      // not something a screen reader has to infer from a tint.
      label: '$label, $state',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconSmall),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: text.labelLarge),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        active ? Icons.visibility : Icons.visibility_off,
                        size: AppSizes.iconSmall,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(child: Text(state, style: text.labelSmall)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // A Column rather than a Row: at large text scales the action's
          // label and the hint cannot share a 320 px line, and a hint that
          // overflows is worse than one that takes an extra line.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.schedule_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(l10n.calendarSelectGroupHint)),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => showTimetableGroupPickerSheet(context),
                  // Names the action, not the source: "Stundenplan" is what
                  // the control above already says.
                  child: Text(l10n.timetableGroupPickerTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary view: a week strip and the chosen day's entries.
///
/// Horizontal swiping moves a day at a time, which is how a phone calendar is
/// expected to behave; the strip above shows where in the week that lands.
class _DayAgendaView extends ConsumerWidget {
  const _DayAgendaView({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime focused = ref.watch(calendarFocusedDayProvider);
    final DateTime today = TimetableWeek.dayOf(DateTime.now());
    final List<CalendarEntry> entries = data.forDay(focused);

    final Map<DateTime, int> counts = <DateTime, int>{};
    for (final CalendarEntry entry in data.entries) {
      final DateTime day = TimetableWeek.dayOf(entry.start);
      counts[day] = (counts[day] ?? 0) + 1;
    }

    return Column(
      children: <Widget>[
        WeekStrip(
          selected: focused,
          today: today,
          entryCounts: counts,
          onSelect: (DateTime day) =>
              ref.read(calendarFocusedDayProvider.notifier).select(day),
          // A swipe on the strip is a week; a swipe on the day below is a day.
          // Two gestures, two areas — neither can swallow the other.
          onShiftWeeks: (int delta) =>
              ref.read(calendarFocusedDayProvider.notifier).shiftWeeks(delta),
          onToday: () => ref.read(calendarFocusedDayProvider.notifier).today(),
        ),
        Expanded(
          child: GestureDetector(
            // A day per swipe. `primaryVelocity` is negative when the finger
            // moves left, which means "forward" in a left-to-right calendar.
            onHorizontalDragEnd: (DragEndDetails details) {
              final double velocity = details.primaryVelocity ?? 0;
              if (velocity == 0) return;
              ref
                  .read(calendarFocusedDayProvider.notifier)
                  .select(focused.add(Duration(days: velocity < 0 ? 1 : -1)));
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: <Widget>[
                ..._calendarHeader(context, data),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      AppDateFormats.weekdayDate(focused, locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      l10n.calendarNoEntriesForDay,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final CalendarEntry entry in entries)
                    _EntryTile(entry: entry, locale: locale),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The optional graphical week.
class _WeekView extends ConsumerWidget {
  const _WeekView({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime focused = ref.watch(calendarFocusedDayProvider);
    final bool showWeekend = ref.watch(calendarShowWeekendProvider);

    return Column(
      children: <Widget>[
        ..._calendarHeader(context, data),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          // A Wrap, not a Row: at a large text size the month and the switch do
          // not share a line on a narrow phone, and the switch dropping onto
          // its own line is better than either of them being cut off.
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                AppDateFormats.monthAndYear(focused, locale),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              // A teaching week is Monday to Friday; the weekend is a local
              // choice. The chip carries a check mark and its label, so the
              // state is never the fill colour alone.
              FilterChip(
                avatar: const Icon(
                  Icons.weekend_outlined,
                  size: AppSizes.iconSmall,
                ),
                label: Text(l10n.calendarWeekendLabel),
                selected: showWeekend,
                onSelected: (_) =>
                    ref.read(calendarShowWeekendProvider.notifier).toggle(),
              ),
            ],
          ),
        ),
        Expanded(
          child: WeekGridView(
            weekStart: TimetableWeek.startOf(focused),
            entries: data.entries,
            today: TimetableWeek.dayOf(DateTime.now()),
            selected: focused,
            dayCount: ref.watch(calendarWeekDayCountProvider),
            onSelectDay: (DateTime day) {
              ref.read(calendarFocusedDayProvider.notifier).select(day);
              // Picking a day in the week grid is how you get to that day.
              ref
                  .read(calendarViewModeProvider.notifier)
                  .set(CalendarViewMode.day);
            },
          ),
        ),
      ],
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    if (data.entries.isEmpty) {
      return ListView(
        children: <Widget>[
          ..._calendarHeader(context, data),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(l10n.calendarNoEntries, textAlign: TextAlign.center),
          ),
        ],
      );
    }

    // Group by day, preserving the merged (ascending) order.
    final List<DateTime> orderedDays = <DateTime>[];
    final Map<DateTime, List<CalendarEntry>> byDay =
        <DateTime, List<CalendarEntry>>{};
    for (final CalendarEntry e in data.entries) {
      final DateTime key = e.day;
      final List<CalendarEntry> list = byDay.putIfAbsent(key, () {
        orderedDays.add(key);
        return <CalendarEntry>[];
      });
      list.add(e);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      children: <Widget>[
        ..._calendarHeader(context, data),
        for (final DateTime day in orderedDays) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              AppDateFormats.weekdayDate(day, locale),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final CalendarEntry e in byDay[day]!)
            _EntryTile(entry: e, locale: locale),
        ],
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.locale});

  final CalendarEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String time = entry.end == null
        ? AppDateFormats.time(entry.start, locale)
        : '${AppDateFormats.time(entry.start, locale)} – '
              '${AppDateFormats.time(entry.end!, locale)}';

    // Source is always conveyed with a text label (and an icon), never by
    // colour alone; the public-calendar colour is an extra decorative accent.
    final String sourceLabel = switch (entry.source) {
      CalendarSource.moodle => l10n.calendarSourceMoodle,
      CalendarSource.timetable => l10n.calendarSourceTimetable,
      CalendarSource.publicCalendar =>
        entry.sourceLabel ?? l10n.calendarSourcePublic,
    };
    final IconData icon = switch (entry.source) {
      CalendarSource.moodle => Icons.event_available_outlined,
      CalendarSource.timetable => Icons.schedule_outlined,
      CalendarSource.publicCalendar => Icons.public_outlined,
    };

    final List<String> subtitleParts = <String>[
      if (entry.subtitle != null && entry.subtitle!.isNotEmpty) entry.subtitle!,
      if (entry.location != null && entry.location!.isNotEmpty) entry.location!,
    ];

    return ListTile(
      leading: entry.colorArgb != null
          ? Container(
              width: AppSizes.icon,
              alignment: Alignment.center,
              child: Container(
                width: AppSizes.iconSmall,
                height: AppSizes.iconSmall,
                decoration: BoxDecoration(
                  color: Color(entry.colorArgb!),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : Icon(icon),
      title: Text(
        entry.title.isEmpty ? sourceLabel : entry.title,
        style: entry.isCancelled
            ? text.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(
        <String>[
          time,
          sourceLabel,
          if (entry.isCancelled) l10n.timetableStatusCancelled,
          ...subtitleParts,
        ].join(' · '),
        style: text.bodySmall,
      ),
      isThreeLine: subtitleParts.isNotEmpty,
    );
  }
}
