// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/loaded.dart';
import '../../moodle/application/moodle_account_controller.dart';
import '../../moodle/application/moodle_controller.dart';
import '../../timetable/application/timetable_providers.dart';
import '../../timetable/application/timetable_week.dart';
import '../../timetable/data/timetable_models.dart';
import '../domain/calendar_entry.dart';
import 'calendar_merge.dart';

/// Month grid or agenda list — the two explicit calendar views.
enum CalendarViewMode { month, list }

class CalendarViewModeController extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.month;

  void set(CalendarViewMode mode) => state = mode;
  void toggle() => state = state == CalendarViewMode.month
      ? CalendarViewMode.list
      : CalendarViewMode.month;
}

final NotifierProvider<CalendarViewModeController, CalendarViewMode>
calendarViewModeProvider =
    NotifierProvider<CalendarViewModeController, CalendarViewMode>(
      CalendarViewModeController.new,
    );

/// The day the calendar is focused on. The visible month and the timetable
/// weeks to load are derived from it, so navigation can never drift apart.
class CalendarFocusedDayController extends Notifier<DateTime> {
  @override
  DateTime build() => TimetableWeek.dayOf(DateTime.now());

  void select(DateTime day) => state = TimetableWeek.dayOf(day);
  void today() => select(DateTime.now());
}

final NotifierProvider<CalendarFocusedDayController, DateTime>
calendarFocusedDayProvider =
    NotifierProvider<CalendarFocusedDayController, DateTime>(
      CalendarFocusedDayController.new,
    );

/// Which sources contribute to the calendar. Both are on by default; the user
/// can hide either without losing the other's data.
class CalendarEnabledSourcesController extends Notifier<Set<CalendarSource>> {
  @override
  Set<CalendarSource> build() => <CalendarSource>{
    CalendarSource.timetable,
    CalendarSource.moodle,
  };

  void toggle(CalendarSource source) {
    final Set<CalendarSource> next = <CalendarSource>{...state};
    if (!next.remove(source)) next.add(source);
    state = next;
  }
}

final NotifierProvider<CalendarEnabledSourcesController, Set<CalendarSource>>
calendarEnabledSourcesProvider =
    NotifierProvider<CalendarEnabledSourcesController, Set<CalendarSource>>(
      CalendarEnabledSourcesController.new,
    );

/// The merged calendar plus per-source status. Every source is isolated: a
/// timetable error never removes Moodle deadlines, and a Moodle error never
/// hides the timetable.
@immutable
class CalendarData {
  const CalendarData({
    required this.entries,
    required this.enabledSources,
    this.timetableLoading = false,
    this.hasTimetableError = false,
    this.needsGroup = false,
    this.moodleConnected = false,
    this.hasMoodleError = false,
  });

  final List<CalendarEntry> entries;
  final Set<CalendarSource> enabledSources;
  final bool timetableLoading;
  final bool hasTimetableError;

  /// No timetable group chosen yet.
  final bool needsGroup;

  final bool moodleConnected;
  final bool hasMoodleError;

  List<CalendarEntry> forDay(DateTime day) => entriesForDay(entries, day);
  Set<DateTime> get eventDays => calendarEventDays(entries);
}

/// The Monday of each week overlapping the month of [day].
List<DateTime> monthWeekStarts(DateTime day) {
  final DateTime firstOfMonth = DateTime(day.year, day.month, 1);
  final DateTime lastOfMonth = DateTime(day.year, day.month + 1, 0);
  final List<DateTime> starts = <DateTime>[];
  DateTime cursor = TimetableWeek.startOf(firstOfMonth);
  while (!cursor.isAfter(lastOfMonth)) {
    starts.add(cursor);
    cursor = TimetableWeek.shift(cursor, TimetableWeek.lengthInDays);
  }
  return starts;
}

/// The aggregated calendar for the focused month.
final Provider<CalendarData> calendarDataProvider = Provider<CalendarData>((
  Ref ref,
) {
  final Set<CalendarSource> enabled = ref.watch(calendarEnabledSourcesProvider);
  final DateTime focused = ref.watch(calendarFocusedDayProvider);

  // --- Source 1: timetable (Campus API), one week provider per visible week.
  final List<CalendarEntry> timetableEntries = <CalendarEntry>[];
  bool timetableLoading = false;
  bool timetableError = false;
  bool needsGroup = false;
  if (enabled.contains(CalendarSource.timetable)) {
    final String? groupId = ref.watch(selectedTimetableGroupIdProvider);
    if (groupId == null) {
      needsGroup = true;
    } else {
      for (final DateTime weekStart in monthWeekStarts(focused)) {
        final AsyncValue<Loaded<Timetable>> week = ref.watch(
          timetableWeekProvider(
            TimetableWeekRequest(groupId: groupId, weekStart: weekStart),
          ),
        );
        week.when(
          data: (Loaded<Timetable> loaded) =>
              timetableEntries.addAll(timetableToCalendarEntries(loaded.value)),
          loading: () => timetableLoading = true,
          error: (_, _) => timetableError = true,
        );
      }
    }
  }

  // --- Source 2: Moodle deadlines (direct, cached). Fully independent.
  final List<CalendarEntry> moodleEntries = <CalendarEntry>[];
  bool moodleError = false;
  final bool moodleConnected =
      ref.watch(moodleAccountControllerProvider).value != null;
  if (enabled.contains(CalendarSource.moodle) && moodleConnected) {
    final MoodleOverviewState? view = ref.watch(moodleControllerProvider).value;
    if (view != null) {
      moodleEntries.addAll(moodleDeadlinesToCalendarEntries(view.deadlines));
      if (view.error != null) moodleError = true;
    }
  }

  return CalendarData(
    entries: mergeCalendarEntries(<CalendarEntry>[
      ...timetableEntries,
      ...moodleEntries,
    ]),
    enabledSources: enabled,
    timetableLoading: timetableLoading,
    hasTimetableError: timetableError,
    needsGroup: needsGroup,
    moodleConnected: moodleConnected,
    hasMoodleError: moodleError,
  );
});
