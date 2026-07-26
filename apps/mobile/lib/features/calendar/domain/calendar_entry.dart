// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// Where a calendar entry originates.
///
/// The set is the single extension point of the cross-source calendar: adding a
/// new source means adding a value here, a mapper to [CalendarEntry], and wiring
/// one contribution in the aggregator. Nothing merges on any server — every
/// source stays in its own feature and is combined only here, on-device.
enum CalendarSource { timetable, moodle }

/// One unified item on the calendar, independent of its source.
@immutable
class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.source,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.subtitle,
    this.location,
    this.isCancelled = false,
  });

  final String id;
  final CalendarSource source;
  final String title;

  /// Absolute instant the entry starts.
  final DateTime start;

  /// Absolute instant the entry ends, if it has a duration.
  final DateTime? end;

  final bool allDay;
  final String? subtitle;
  final String? location;

  /// A cancelled timetable slot — conveyed with icon + text, never colour only.
  final bool isCancelled;

  /// The local calendar day the entry falls on (midnight, local time).
  DateTime get day => DateTime(start.year, start.month, start.day);

  @override
  bool operator ==(Object other) =>
      other is CalendarEntry &&
      other.id == id &&
      other.source == source &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay &&
      other.subtitle == subtitle &&
      other.location == location &&
      other.isCancelled == isCancelled;

  @override
  int get hashCode => Object.hash(
    id,
    source,
    title,
    start,
    end,
    allDay,
    subtitle,
    location,
    isCancelled,
  );
}

/// Normalises any [DateTime] to a local midnight day key, so entries and the
/// month grid agree on what "the same day" means.
DateTime calendarDayKey(DateTime value) =>
    DateTime(value.year, value.month, value.day);
