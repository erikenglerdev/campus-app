// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Where in the day the user currently is.
///
/// The dashboard is meant to lead through a day, so it needs to know whether
/// "today" still has anything left in it. Deriving that from the clock in one
/// pure function keeps every card consistent — and testable without waiting
/// for a real time of day.
enum DayPhase {
  /// Before teaching starts. The day is still ahead.
  earlyMorning,

  /// Teaching hours. "Now" and "next" are the interesting questions.
  daytime,

  /// After teaching but before the night rolls over. What is left of today.
  evening,

  /// So late that tomorrow is the more useful answer than today.
  night;

  /// Whether the dashboard should lead with the next day rather than this one.
  ///
  /// Late at night "today" is over; showing an empty agenda would be correct
  /// and useless at the same time.
  bool get prefersNextDay => this == DayPhase.night;
}

/// Boundaries of the teaching day, in local time.
///
/// Deliberately generous and **not** derived from a semester calendar the app
/// does not have: these decide presentation only, never whether data is
/// fetched, so being an hour off costs nothing.
abstract final class TeachingDay {
  static const int startHour = 7;
  static const int endHour = 18;
  static const int nightHour = 22;

  static DayPhase phaseAt(DateTime now) {
    final int hour = now.hour;
    if (hour >= nightHour || hour < 5) return DayPhase.night;
    if (hour < startHour) return DayPhase.earlyMorning;
    if (hour < endHour) return DayPhase.daytime;
    return DayPhase.evening;
  }

  /// The day the dashboard should describe — today, or tomorrow when today is
  /// effectively over.
  static DateTime focusDate(DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    return phaseAt(now).prefersNextDay
        ? today.add(const Duration(days: 1))
        : today;
  }

  /// Whether [now] falls inside `[start, end)`.
  static bool isOngoing(DateTime now, DateTime start, DateTime end) =>
      !now.isBefore(start) && now.isBefore(end);
}
