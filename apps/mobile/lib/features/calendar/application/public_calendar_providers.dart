// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../../timetable/application/timetable_week.dart';
import '../data/public_calendars_repository.dart';
import '../domain/calendar_entry.dart';
import '../domain/public_calendar.dart';
import 'calendar_merge.dart';
import 'calendar_providers.dart';
import 'public_calendar_selection.dart';

/// The public-calendar catalogue. Fetching it also folds `defaultSubscribed`
/// into the local selection exactly once per slug (the single place defaults
/// are applied), mirroring the news-channel wiring.
final FutureProvider<Loaded<List<PublicCalendar>>>
publicCalendarsCatalogProvider = FutureProvider<Loaded<List<PublicCalendar>>>((
  Ref ref,
) async {
  final String locale = ref.watch(localeCodeProvider);
  final Loaded<List<PublicCalendar>> loaded = await ref
      .watch(publicCalendarsRepositoryProvider)
      .fetchCalendars(locale: locale);
  await ref
      .read(publicCalendarSelectionProvider.notifier)
      .reconcile(loaded.value);
  return loaded;
}, retry: (_, _) => null);

/// Bounds of the visible month (± a week), as YYYY-MM-DD, for the events query.
({String from, String to}) _monthWindow(DateTime focused) {
  final List<DateTime> weeks = monthWeekStarts(focused);
  final DateTime from = weeks.first;
  final DateTime to = TimetableWeek.shift(
    weeks.last,
    TimetableWeek.lengthInDays,
  );
  String iso(DateTime d) => d.toIso8601String().slice10();
  return (from: iso(from), to: iso(to));
}

/// Public-calendar events for the currently selected calendars in the focused
/// month, already mapped to source-neutral [CalendarEntry] values.
///
/// Returns an empty list when nothing is selected — an empty selection means
/// "no public events", never "all". A failure here is isolated by the
/// aggregator and never hides the timetable or Moodle.
final FutureProvider<List<CalendarEntry>> publicCalendarMonthEntriesProvider =
    FutureProvider<List<CalendarEntry>>((Ref ref) async {
      final DateTime focused = ref.watch(calendarFocusedDayProvider);
      final String locale = ref.watch(localeCodeProvider);
      final List<PublicCalendar> catalog =
          ref.watch(publicCalendarsCatalogProvider).value?.value ??
          const <PublicCalendar>[];
      final PublicCalendarSelectionState selection = ref.watch(
        publicCalendarSelectionProvider,
      );
      final List<String> slugs =
          PublicCalendarSelectionRules.effectiveSelection(
            available: catalog,
            selected: selection.selectedSlugs,
          );
      if (slugs.isEmpty) return const <CalendarEntry>[];

      final ({String from, String to}) window = _monthWindow(focused);
      final Loaded<List<PublicCalendarEvent>> loaded = await ref
          .watch(publicCalendarsRepositoryProvider)
          .fetchEvents(
            locale: locale,
            slugs: slugs,
            from: window.from,
            to: window.to,
          );
      final Map<String, PublicCalendar> bySlug = <String, PublicCalendar>{
        for (final PublicCalendar c in catalog) c.slug: c,
      };
      return publicCalendarEventsToCalendarEntries(loaded.value, bySlug);
    }, retry: (_, _) => null);

extension _Slice on String {
  /// The `YYYY-MM-DD` prefix of an ISO-8601 string.
  String slice10() => length >= 10 ? substring(0, 10) : this;
}
