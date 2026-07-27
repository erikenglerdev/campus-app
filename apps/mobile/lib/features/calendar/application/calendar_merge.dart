// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import '../../../core/theme/hex_color.dart';
import '../../moodle/domain/moodle_deadline.dart';
import '../../timetable/data/timetable_models.dart';
import '../domain/calendar_entry.dart';
import '../domain/public_calendar.dart';

/// Pure mapping + aggregation for the cross-source calendar.
///
/// Every source is turned into [CalendarEntry] values by its own mapper, and the
/// lists are merged, deduplicated and sorted here — entirely on-device. No
/// server ever sees the combined set, and one source's data is never derived
/// from another's.

/// Maps a Campus-API timetable to calendar entries.
List<CalendarEntry> timetableToCalendarEntries(Timetable timetable) {
  final List<CalendarEntry> out = <CalendarEntry>[];
  for (final TimetableDay day in timetable.days) {
    for (final TimetableEntry entry in day.entries) {
      final String location = entry.rooms
          .map((TimetableRoom r) => r.label)
          .join(', ');
      final String teachers = entry.teachers
          .map((TimetableTeacher t) => t.label)
          .join(', ');
      out.add(
        CalendarEntry(
          id: 'timetable:${entry.id}',
          source: CalendarSource.timetable,
          title: entry.displayTitle ?? '',
          start: entry.start,
          end: entry.end,
          subtitle: teachers.isEmpty ? null : teachers,
          location: location.isEmpty ? null : location,
          isCancelled: entry.status == TimetableEntryStatus.cancelled,
        ),
      );
    }
  }
  return out;
}

/// Maps direct-from-Moodle deadlines to calendar entries.
List<CalendarEntry> moodleDeadlinesToCalendarEntries(
  List<MoodleDeadline> deadlines,
) {
  return deadlines
      .map(
        (MoodleDeadline d) => CalendarEntry(
          id: 'moodle:${d.id}',
          source: CalendarSource.moodle,
          title: d.title,
          start: d.dueAt,
          subtitle: d.courseName,
        ),
      )
      .toList();
}

/// Maps aggregated public-calendar events to calendar entries, resolving each
/// event's colour and display name from the catalogue (by slug). The colour is
/// only a decorative accent — the calendar name is always carried too.
List<CalendarEntry> publicCalendarEventsToCalendarEntries(
  List<PublicCalendarEvent> events,
  Map<String, PublicCalendar> bySlug,
) {
  return events.map((PublicCalendarEvent e) {
    final PublicCalendar? calendar = bySlug[e.calendarSlug];
    return CalendarEntry(
      id: 'publicCalendar:${e.calendarSlug}:${e.id}',
      source: CalendarSource.publicCalendar,
      title: e.title.isEmpty ? (calendar?.name ?? e.calendarSlug) : e.title,
      start: e.start,
      end: e.end,
      allDay: e.allDay,
      isCancelled: e.status == 'cancelled',
      // The room comes from the ICS LOCATION, the description from DESCRIPTION —
      // both only present when the calendar enables showLocation/showDescription.
      subtitle: e.description,
      location: e.location,
      calendarSlug: e.calendarSlug,
      sourceLabel: calendar?.name ?? e.calendarSlug,
      colorArgb: parseHexColorArgb(calendar?.colorHex),
    );
  }).toList();
}

/// Merges entries from any number of sources: deduplicates by [CalendarEntry.id]
/// and returns them sorted ascending by start.
List<CalendarEntry> mergeCalendarEntries(Iterable<CalendarEntry> entries) {
  final Map<String, CalendarEntry> byId = <String, CalendarEntry>{};
  for (final CalendarEntry e in entries) {
    byId[e.id] = e;
  }
  final List<CalendarEntry> merged = byId.values.toList()
    ..sort((CalendarEntry a, CalendarEntry b) => a.start.compareTo(b.start));
  return merged;
}

/// The entries falling on [day] (local time), sorted by start.
List<CalendarEntry> entriesForDay(List<CalendarEntry> entries, DateTime day) {
  final DateTime key = calendarDayKey(day);
  final List<CalendarEntry> out =
      entries.where((CalendarEntry e) => e.day == key).toList()..sort(
        (CalendarEntry a, CalendarEntry b) => a.start.compareTo(b.start),
      );
  return out;
}

/// The distinct local day keys that have at least one entry.
Set<DateTime> calendarEventDays(List<CalendarEntry> entries) =>
    entries.map((CalendarEntry e) => e.day).toSet();
