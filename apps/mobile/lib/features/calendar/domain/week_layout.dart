// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import 'calendar_entry.dart';

/// One entry placed on the time grid.
///
/// [lane] and [laneCount] describe how a group of overlapping entries shares
/// the width of its day column: lane 1 of 3 sits in the middle third.
@immutable
class PlacedEntry {
  const PlacedEntry({
    required this.entry,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEntry entry;

  /// Minutes since midnight.
  final int startMinute;
  final int endMinute;

  final int lane;
  final int laneCount;

  int get durationMinutes => endMinute - startMinute;
}

/// The vertical extent the grid has to draw.
@immutable
class GridRange {
  const GridRange({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;

  int get hourCount => endHour - startHour;
}

/// Turns a day's entries into positioned boxes.
///
/// Everything here is arithmetic on minutes, deliberately kept out of the
/// widget: overlap handling is the only genuinely tricky part of a week grid,
/// and it is far easier to get right — and to keep right — as a pure function
/// with tests than as a layout side effect.
///
/// **Every reading of a clock here goes through [_local] first.** The API sends
/// absolute instants, so `entry.start.hour` is the hour in UTC — two hours off
/// in a German summer, one in winter, arbitrary abroad. Every other view
/// formats via `toLocal()`, and a grid that disagreed with the day agenda about
/// when a lecture starts would be worse than no grid.
abstract final class WeekLayout {
  static DateTime _local(DateTime value) => value.toLocal();

  /// A lecture shorter than this is still drawn this tall, so a 15-minute slot
  /// stays readable and tappable instead of collapsing to a line.
  static const int minimumVisibleMinutes = 30;

  /// The hours the grid spans, derived from the entries.
  ///
  /// Falls back to the teaching day when there is nothing to show, so an empty
  /// week still looks like a calendar rather than a blank box. Always covers
  /// whole hours, and never fewer than [minimumHours] so the grid cannot
  /// degenerate into a single stripe.
  static GridRange rangeFor(
    Iterable<CalendarEntry> entries, {
    int defaultStartHour = 8,
    int defaultEndHour = 18,
    int minimumHours = 4,
  }) {
    final List<CalendarEntry> timed = entries
        .where((CalendarEntry e) => !e.allDay)
        .toList();
    if (timed.isEmpty) {
      return GridRange(startHour: defaultStartHour, endHour: defaultEndHour);
    }

    int earliest = 24;
    int latest = 0;
    for (final CalendarEntry entry in timed) {
      final int start = _local(entry.start).hour;
      final DateTime end = _local(entry.end ?? entry.start);
      // An entry ending exactly on the hour does not need the next row.
      final int endHour = end.minute == 0 ? end.hour : end.hour + 1;
      if (start < earliest) earliest = start;
      if (endHour > latest) latest = endHour;
    }
    earliest = earliest.clamp(0, 23);
    latest = latest.clamp(1, 24);
    if (latest - earliest < minimumHours) {
      latest = (earliest + minimumHours).clamp(1, 24);
      if (latest - earliest < minimumHours) {
        earliest = (latest - minimumHours).clamp(0, 23);
      }
    }
    return GridRange(startHour: earliest, endHour: latest);
  }

  /// Places one day's timed entries, splitting overlaps into lanes.
  ///
  /// Entries that overlap in time share the column width. The grouping is by
  /// *cluster*: A overlapping B and B overlapping C puts all three in one
  /// group even when A and C do not touch, because otherwise B would have to
  /// be in two widths at once.
  static List<PlacedEntry> placeDay(Iterable<CalendarEntry> entries) {
    final List<CalendarEntry> timed =
        entries.where((CalendarEntry e) => !e.allDay).toList()
          ..sort((CalendarEntry a, CalendarEntry b) {
            final int byStart = a.start.compareTo(b.start);
            return byStart != 0 ? byStart : a.id.compareTo(b.id);
          });
    if (timed.isEmpty) return const <PlacedEntry>[];

    int startOf(CalendarEntry e) {
      final DateTime start = _local(e.start);
      return start.hour * 60 + start.minute;
    }

    int endOf(CalendarEntry e) {
      final DateTime end = _local(e.end ?? e.start);
      final int minutes = end.hour * 60 + end.minute;
      return minutes < startOf(e) + minimumVisibleMinutes
          ? startOf(e) + minimumVisibleMinutes
          : minutes;
    }

    final List<PlacedEntry> placed = <PlacedEntry>[];
    List<CalendarEntry> cluster = <CalendarEntry>[];
    int clusterEnd = -1;

    void flush() {
      if (cluster.isEmpty) return;
      // Greedy lane assignment: reuse the first lane whose last entry ended.
      final List<int> laneEnds = <int>[];
      final List<int> lanes = <int>[];
      for (final CalendarEntry entry in cluster) {
        int lane = laneEnds.indexWhere((int end) => end <= startOf(entry));
        if (lane == -1) {
          laneEnds.add(endOf(entry));
          lane = laneEnds.length - 1;
        } else {
          laneEnds[lane] = endOf(entry);
        }
        lanes.add(lane);
      }
      for (int i = 0; i < cluster.length; i++) {
        placed.add(
          PlacedEntry(
            entry: cluster[i],
            startMinute: startOf(cluster[i]),
            endMinute: endOf(cluster[i]),
            lane: lanes[i],
            laneCount: laneEnds.length,
          ),
        );
      }
      cluster = <CalendarEntry>[];
      clusterEnd = -1;
    }

    for (final CalendarEntry entry in timed) {
      if (cluster.isNotEmpty && startOf(entry) >= clusterEnd) flush();
      cluster.add(entry);
      final int end = endOf(entry);
      if (end > clusterEnd) clusterEnd = end;
    }
    flush();
    return List<PlacedEntry>.unmodifiable(placed);
  }
}
