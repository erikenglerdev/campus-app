// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../../moodle/application/moodle_account_controller.dart';
import '../../moodle/application/moodle_controller.dart';
import '../../timetable/presentation/timetable_group_picker_sheet.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_entry.dart';

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
    final AppLocalizations l10n = context.l10n;
    final CalendarViewMode mode = ref.watch(calendarViewModeProvider);
    final CalendarData data = ref.watch(calendarDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.calendarManageTooltip,
            onPressed: () => context.push(AppRoutes.calendarManage),
            icon: const Icon(Icons.tune_outlined),
          ),
          IconButton(
            tooltip: l10n.calendarToday,
            onPressed: () =>
                ref.read(calendarFocusedDayProvider.notifier).today(),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Only the toggle is fixed; everything else scrolls with the view,
            // so nothing can overflow a short viewport.
            _ViewToggle(mode: mode),
            Expanded(
              child: mode == CalendarViewMode.month
                  ? _MonthView(data: data)
                  : _ListView(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrollable header shared by both views: source filters, per-source error
/// banners and (when needed) the "pick a group" hint.
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
    _SourceFilters(data: data),
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
            value: CalendarViewMode.month,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(l10n.calendarViewMonth),
          ),
          ButtonSegment<CalendarViewMode>(
            value: CalendarViewMode.list,
            icon: const Icon(Icons.view_agenda_outlined),
            label: Text(l10n.calendarViewList),
          ),
        ],
        selected: <CalendarViewMode>{mode},
        onSelectionChanged: (Set<CalendarViewMode> selection) =>
            ref.read(calendarViewModeProvider.notifier).set(selection.first),
      ),
    );
  }
}

class _SourceFilters extends ConsumerWidget {
  const _SourceFilters({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          FilterChip(
            avatar: const Icon(
              Icons.schedule_outlined,
              size: AppSizes.iconSmall,
            ),
            label: Text(l10n.calendarSourceTimetable),
            selected: data.enabledSources.contains(CalendarSource.timetable),
            onSelected: (_) => ref
                .read(calendarEnabledSourcesProvider.notifier)
                .toggle(CalendarSource.timetable),
          ),
          FilterChip(
            avatar: const Icon(
              Icons.cast_for_education_outlined,
              size: AppSizes.iconSmall,
            ),
            label: Text(l10n.calendarSourceMoodle),
            selected: data.enabledSources.contains(CalendarSource.moodle),
            onSelected: data.moodleConnected
                ? (_) => ref
                      .read(calendarEnabledSourcesProvider.notifier)
                      .toggle(CalendarSource.moodle)
                : null,
          ),
        ],
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
          child: Row(
            children: <Widget>[
              const Icon(Icons.schedule_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(l10n.calendarSelectGroupHint)),
              TextButton(
                onPressed: () => showTimetableGroupPickerSheet(context),
                child: Text(l10n.calendarSourceTimetable),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime focused = ref.watch(calendarFocusedDayProvider);
    final DateTime now = DateTime.now();
    final List<CalendarEntry> dayEntries = data.forDay(focused);

    // The header, grid and day agenda scroll together, so they never overflow a
    // short viewport.
    return ListView(
      children: <Widget>[
        ..._calendarHeader(context, data),
        TableCalendar<CalendarEntry>(
          locale: locale,
          firstDay: DateTime(now.year - 1),
          lastDay: DateTime(now.year + 2),
          focusedDay: focused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          availableCalendarFormats: const <CalendarFormat, String>{
            CalendarFormat.month: '',
          },
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          selectedDayPredicate: (DateTime d) => isSameDay(d, focused),
          eventLoader: data.forDay,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: (DateTime selected, DateTime _) =>
              ref.read(calendarFocusedDayProvider.notifier).select(selected),
          onPageChanged: (DateTime page) =>
              ref.read(calendarFocusedDayProvider.notifier).select(page),
        ),
        const Divider(height: 1),
        if (dayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              context.l10n.calendarNoEntriesForDay,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final CalendarEntry e in dayEntries)
            _EntryTile(entry: e, locale: locale),
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
