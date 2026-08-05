// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../timetable/application/timetable_week.dart';
import '../domain/calendar_entry.dart';
import '../domain/week_layout.dart';

/// A week as a time grid: one column per drawn day over an hour axis.
///
/// The drawn days **share the available width**, so the teaching week is on
/// screen at a glance — a week you have to scroll sideways to finish is not a
/// week you can see. Only when a column would fall below a touch target does
/// the grid stop shrinking and scroll horizontally instead, which on a narrow
/// phone is what the weekend does. The hour gutter stays put either way, so
/// the time is never scrolled off.
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
    required this.dayCount,
    required this.onSelectDay,
    super.key,
  });

  final DateTime weekStart;
  final List<CalendarEntry> entries;
  final DateTime today;
  final DateTime selected;

  /// How many days from [weekStart] are drawn — five for the teaching week,
  /// seven once the reader switches the weekend on.
  final int dayCount;

  final ValueChanged<DateTime> onSelectDay;

  /// The narrowest a day column may get before the grid scrolls instead.
  ///
  /// A column is the tap target of its day header, so it does not go below one.
  static const double minColumnWidth = AppSizes.minTouchTarget;

  /// The width of one column when [dayCount] days share [available] pixels.
  static double columnWidthFor(double available, int dayCount) {
    if (dayCount <= 0) return minColumnWidth;
    final double shared = available / dayCount;
    return shared >= minColumnWidth ? shared : minColumnWidth;
  }

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

  bool _sameDay(DateTime a, DateTime b) {
    // Local, for the same reason WeekLayout converts: an entry at 00:30 in
    // Köthen is the previous day in UTC and would land in the wrong column.
    final DateTime x = a.toLocal();
    final DateTime y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final List<DateTime> days = <DateTime>[
      for (int i = 0; i < widget.dayCount; i++)
        TimetableWeek.shift(widget.weekStart, i),
    ];
    // Entries outside the drawn days are dropped here rather than in the
    // caller: the hour range has to come from what is actually on screen, or a
    // hidden Sunday evening would stretch every weekday column.
    final List<CalendarEntry> visible = widget.entries
        .where(
          (CalendarEntry e) =>
              days.any((DateTime day) => _sameDay(e.start, day)),
        )
        .toList(growable: false);
    final GridRange range = WeekLayout.rangeFor(visible);
    final double hourHeight = WeekGridView.hourHeightOf(context);
    final double headerHeight = WeekGridView.headerHeightOf(context);

    List<CalendarEntry> entriesOn(DateTime day) => visible
        .where((CalendarEntry e) => _sameDay(e.start, day))
        .toList(growable: false);

    final List<CalendarEntry> allDay = visible
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
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double columnWidth = WeekGridView.columnWidthFor(
                      constraints.maxWidth,
                      days.length,
                    );
                    return SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: columnWidth * days.length,
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
                                      width: columnWidth,
                                      isToday: _sameDay(day, widget.today),
                                      isSelected: _sameDay(
                                        day,
                                        widget.selected,
                                      ),
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
                                          width: columnWidth,
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
                    );
                  },
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
    required this.width,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final String locale;
  final double width;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
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
    required this.width,
    required this.hourHeight,
    required this.isToday,
  });

  final List<PlacedEntry> placed;
  final GridRange range;
  final String locale;
  final double width;
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
      width: width,
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
            // Hour lines. Positioned against the SAME height the entries use:
            // drawing them at the unscaled constant put a 10:00 lecture next to
            // the 08:00 mark as soon as the reader scaled the text up.
            for (int h = 0; h <= range.hourCount; h++)
              Positioned(
                top: h * hourHeight,
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
                left: (width / item.laneCount) * item.lane + 1,
                width: width / item.laneCount - 2,
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
