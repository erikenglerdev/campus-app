// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../timetable/application/timetable_week.dart';

/// A compact seven-day strip above the agenda.
///
/// Replaces the month grid as the primary way to move around: on a phone a
/// month grid costs most of the screen and answers a question ("which day?")
/// that a week strip answers in a fifth of the space.
///
/// The strip is swiped sideways to change week — one week per swipe, keeping
/// the selected weekday, arbitrarily far in either direction. The day content
/// below keeps its own day-at-a-time swipe; the two never meet, because a
/// gesture belongs to whichever of the two the finger started on.
///
/// It shows all seven days even when the week **view** is set to Monday to
/// Friday: this is the day picker, and a Saturday has to stay reachable.
///
/// A day that has entries is marked by a **dot as well as** its weight, and
/// today additionally by an outline — never by colour alone.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.selected,
    required this.today,
    required this.entryCounts,
    required this.onSelect,
    required this.onShiftWeeks,
    required this.onToday,
    super.key,
  });

  final DateTime selected;
  final DateTime today;

  /// Number of entries per day, used for the marker and the screen-reader
  /// description. Missing means zero.
  final Map<DateTime, int> entryCounts;

  final ValueChanged<DateTime> onSelect;

  /// Called with `+1`/`-1` when the strip is swiped.
  final ValueChanged<int> onShiftWeeks;

  final VoidCallback onToday;

  bool get _isCurrentWeek =>
      TimetableWeek.startOf(selected) == TimetableWeek.startOf(today);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime start = TimetableWeek.startOf(selected);

    return Semantics(
      container: true,
      label: l10n.calendarWeekStripSemantic(
        AppDateFormats.weekdayDate(selected, locale),
      ),
      child: GestureDetector(
        // One week per swipe regardless of how far or how fast the finger
        // travelled: a calendar that jumped three weeks on a quick flick would
        // be impossible to aim.
        onHorizontalDragEnd: (DragEndDetails details) {
          final double velocity = details.primaryVelocity ?? 0;
          if (velocity == 0) return;
          onShiftWeeks(velocity < 0 ? 1 : -1);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  // Day numbers alone do not say which month you swiped into.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: Text(
                        AppDateFormats.monthAndYear(selected, locale),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  // Offered only when there is something to go back to.
                  if (!_isCurrentWeek)
                    TextButton(
                      onPressed: onToday,
                      child: Text(l10n.calendarToday),
                    ),
                ],
              ),
              Row(
                children: <Widget>[
                  for (int i = 0; i < TimetableWeek.lengthInDays; i++)
                    Expanded(
                      child: _DayCell(
                        day: TimetableWeek.shift(start, i),
                        selected: selected,
                        today: today,
                        entryCount:
                            entryCounts[TimetableWeek.shift(start, i)] ?? 0,
                        onSelect: onSelect,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.entryCount,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime selected;
  final DateTime today;
  final int entryCount;
  final ValueChanged<DateTime> onSelect;

  bool get _isSelected => _sameDay(day, selected);
  bool get _isToday => _sameDay(day, today);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    return Semantics(
      button: true,
      selected: _isSelected,
      label: AppDateFormats.weekdayDate(day, locale),
      value: entryCount > 0 ? l10n.calendarDayHasEntries(entryCount) : null,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => onSelect(day),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: _isSelected ? colors.primaryContainer : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              // Today keeps an outline even when another day is selected, so
              // "where am I" never depends on telling two fills apart.
              border: _isToday
                  ? Border.all(color: colors.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppDateFormats.shortWeekday(day, locale),
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  AppDateFormats.dayOfMonth(day, locale),
                  style: text.labelLarge?.copyWith(
                    fontWeight: _isSelected ? FontWeight.w700 : null,
                    color: _isSelected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
                // The marker is a shape, not a hue.
                SizedBox(
                  height: 6,
                  child: entryCount > 0
                      ? Icon(
                          Icons.circle,
                          size: 5,
                          color: _isSelected
                              ? colors.onPrimaryContainer
                              : colors.primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
