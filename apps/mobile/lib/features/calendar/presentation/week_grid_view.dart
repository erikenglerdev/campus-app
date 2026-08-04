// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../timetable/application/timetable_week.dart';
import '../domain/calendar_entry.dart';
import '../domain/week_layout.dart';

/// A week as a time grid: seven day columns over an hour axis.
///
/// The grid scrolls **horizontally**. Seven columns squeezed into a 320 px
/// phone would be 40 px each — narrower than a touch target and too narrow for
/// a single word — so each column keeps a usable minimum width and the week
/// scrolls, the way phone calendars have solved this for years. The hour
/// gutter stays put so you never lose the time while scrolling sideways.
///
/// Offered as an option, not as the default: the day agenda answers "what is
/// on" in far less space. This view answers "how is my week shaped", which is
/// a different and rarer question.
class WeekGridView extends StatefulWidget {
  const WeekGridView({
    required this.weekStart,
    required this.entries,
    required this.today,
    required this.selected,
    required this.onSelectDay,
    super.key,
  });

  final DateTime weekStart;
  final List<CalendarEntry> entries;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelectDay;

  /// Minimum width of one day column.
  static const double columnWidth = 96;

  /// Height of one hour row at the default text size.
  static const double hourHeight = 56;

  /// Height of the day-header row at the default text size.
  static const double headerHeight = 32;

  /// Width of the fixed hour gutter.
  static const double gutterWidth = 44;

  /// The row heights actually used, grown with the reader's text size.
  ///
  /// A row is the only thing standing between an entry and its label: at twice
  /// the text size a fixed 56 px hour leaves a half-hour box shorter than a
  /// single line, and the title would be cut mid-glyph. Growing the grid keeps
  /// the layout honest instead — the week simply becomes taller and scrolls.
  static double hourHeightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(hourHeight);

  static double headerHeightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(headerHeight);

  @override
  State<WeekGridView> createState() => _WeekGridViewState();
}

class _WeekGridViewState extends State<WeekGridView> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final List<DateTime> days = <DateTime>[
      for (int i = 0; i < TimetableWeek.lengthInDays; i++)
        TimetableWeek.shift(widget.weekStart, i),
    ];
    final GridRange range = WeekLayout.rangeFor(widget.entries);
    final double hourHeight = WeekGridView.hourHeightOf(context);
    final double headerHeight = WeekGridView.headerHeightOf(context);

    List<CalendarEntry> entriesOn(DateTime day) => widget.entries
        .where((CalendarEntry e) => _sameDay(e.start, day))
        .toList(growable: false);

    final List<CalendarEntry> allDay = widget.entries
        .where((CalendarEntry e) => e.allDay)
        .toList(growable: false);

    return Column(
      children: <Widget>[
        // All-day items get their own band: they have no place on a time axis,
        // and stretching one across the whole column would bury the rest.
        if (allDay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  l10n.calendarWeekAllDay,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    allDay.map((CalendarEntry e) => e.title).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Fixed hour gutter, scrolled vertically in step with the grid.
              SizedBox(
                width: WeekGridView.gutterWidth,
                child: Column(
                  children: <Widget>[
                    SizedBox(height: headerHeight),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _vertical,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: <Widget>[
                            for (
                              int h = range.startHour;
                              h < range.endHour;
                              h++
                            )
                              SizedBox(
                                height: hourHeight,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.xs,
                                    ),
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                      style: text.labelSmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: WeekGridView.columnWidth * days.length,
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: headerHeight,
                          child: Row(
                            children: <Widget>[
                              for (final DateTime day in days)
                                _DayHeader(
                                  day: day,
                                  locale: locale,
                                  isToday: _sameDay(day, widget.today),
                                  isSelected: _sameDay(day, widget.selected),
                                  onTap: () => widget.onSelectDay(day),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _vertical,
                            child: SizedBox(
                              height: hourHeight * range.hourCount,
                              child: Row(
                                children: <Widget>[
                                  for (final DateTime day in days)
                                    _DayColumn(
                                      placed: WeekLayout.placeDay(
                                        entriesOn(day),
                                      ),
                                      range: range,
                                      locale: locale,
                                      hourHeight: hourHeight,
                                      isToday: _sameDay(day, widget.today),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.locale,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final String locale;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: WeekGridView.columnWidth,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: AppDateFormats.weekdayDate(day, locale),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryContainer : null,
              // Today keeps an outline of its own, so "where am I" never
              // depends on telling two fills apart.
              border: isToday
                  ? Border.all(color: colors.primary, width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                '${AppDateFormats.shortWeekday(day, locale)} '
                '${AppDateFormats.dayOfMonth(day, locale)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.placed,
    required this.range,
    required this.locale,
    required this.hourHeight,
    required this.isToday,
  });

  final List<PlacedEntry> placed;
  final GridRange range;
  final String locale;
  final double hourHeight;
  final bool isToday;

  static IconData _iconFor(CalendarSource source) => switch (source) {
    CalendarSource.timetable => Icons.school_outlined,
    CalendarSource.moodle => Icons.assignment_outlined,
    CalendarSource.publicCalendar => Icons.public,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double pxPerMinute = hourHeight / 60;
    final int gridStart = range.startHour * 60;
    final TextStyle? titleStyle = Theme.of(context).textTheme.labelSmall;

    // Measured once per column rather than per entry: how tall one line of the
    // title actually is at the reader's text size decides how many lines fit
    // into a box, and guessing from `fontSize` alone is wrong as soon as a
    // font, a locale or a text scaler disagrees.
    final TextPainter probe = TextPainter(
      text: TextSpan(text: 'Hg', style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double lineHeight = probe.height;
    probe.dispose();

    return SizedBox(
      width: WeekGridView.columnWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday
              ? colors.primaryContainer.withValues(alpha: 0.18)
              : null,
          border: Border(
            left: BorderSide(color: colors.outline.withValues(alpha: 0.24)),
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Hour lines.
            for (int h = 0; h <= range.hourCount; h++)
              Positioned(
                top: h * WeekGridView.hourHeight,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.outline.withValues(alpha: 0.16),
                ),
              ),
            for (final PlacedEntry item in placed)
              Positioned(
                top: (item.startMinute - gridStart) * pxPerMinute,
                height: item.durationMinutes * pxPerMinute,
                left:
                    (WeekGridView.columnWidth / item.laneCount) * item.lane + 1,
                width: WeekGridView.columnWidth / item.laneCount - 2,
                child: Semantics(
                  label: l10n.calendarWeekSemantic(
                    item.entry.title,
                    AppDateFormats.time(item.entry.start, locale),
                    AppDateFormats.time(
                      item.entry.end ?? item.entry.start,
                      locale,
                    ),
                  ),
                  excludeSemantics: true,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: colors.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              // A box is only as tall as its entry is long, and
                              // the shortest is barely one line. Work out how
                              // many whole lines fit and ellipsise the rest —
                              // stacking the icon above the title would leave
                              // the text a few pixels and cut the glyphs in
                              // half, which reads as a rendering fault rather
                              // than as a short appointment.
                              final int lines = lineHeight <= 0
                                  ? 1
                                  : (constraints.maxHeight / lineHeight)
                                        .floor()
                                        .clamp(1, 4);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // Icon and text, never colour alone.
                                  Icon(
                                    _iconFor(item.entry.source),
                                    size: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Expanded(
                                    child: Text(
                                      item.entry.title,
                                      style: titleStyle,
                                      maxLines: lines,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
