// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/locale/formatters.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/l10n.dart';
import '../../../calendar/application/calendar_providers.dart';
import '../../../calendar/domain/calendar_entry.dart';
import 'dashboard_section.dart';

/// Which slice of the day an [AgendaCard] shows.
enum AgendaMode {
  /// What is on right now, or what comes next.
  currentOrNext,

  /// Everything still ahead, minus the entry the other card already leads with.
  restOfDay,
}

/// The day's appointments, merged from every enabled calendar source.
///
/// Reads [dayAgendaProvider] for an explicit date, so the card is unaffected by
/// whichever month the calendar screen happens to be browsing.
///
/// A source that fails is reported by the aggregator without hiding the others,
/// which is why this card can show a timetable entry while the public calendars
/// are down.
class AgendaCard extends ConsumerWidget {
  const AgendaCard({
    required this.now,
    required this.date,
    required this.mode,
    super.key,
  });

  final DateTime now;
  final DateTime date;
  final AgendaMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DayAgenda agenda = ref.watch(dayAgendaProvider(date));

    final CalendarEntry? lead = agenda.currentOrNext(now);
    final List<CalendarEntry> rest = agenda.upcomingAfter(now);
    final bool isLead = mode == AgendaMode.currentOrNext;

    // The "rest of day" card adds nothing when there is no rest; an empty
    // second card would be noise directly under the first one.
    if (!isLead && rest.isEmpty) return const SizedBox.shrink();

    final bool ongoing =
        lead != null &&
        !lead.allDay &&
        !now.isBefore(lead.start) &&
        now.isBefore(lead.end ?? lead.start);

    return DashboardSection(
      title: isLead
          ? (ongoing ? l10n.todayNowLabel : l10n.todayNextLabel)
          : l10n.todayAgendaTitle,
      icon: isLead ? Icons.schedule : Icons.event_note_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.calendar),
      child: switch ((isLead, lead, agenda.isLoading)) {
        (true, null, true) => const _AgendaLoading(),
        (true, null, false) => DashboardLine(
          agenda.allSourcesFailed
              ? l10n.todayCardFailed
              : l10n.todayNoMoreToday,
        ),
        (true, final CalendarEntry entry, _) => _EntryLine(
          entry: entry,
          emphasised: true,
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final CalendarEntry entry in rest.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _EntryLine(entry: entry),
              ),
            if (rest.length > 3)
              Text(
                l10n.todayMoreEntries(rest.length - 3),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      },
    );
  }
}

/// One entry: time, title and its source.
///
/// The source is carried by an **icon and a word**, never by colour alone —
/// a colour-only legend is unusable for a large share of users.
class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.entry, this.emphasised = false});

  final CalendarEntry entry;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).languageCode;

    final String when = entry.allDay
        ? l10n.todayAllDayLabel
        : AppDateFormats.time(entry.start, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text(
                when,
                style: text.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: emphasised ? text.titleSmall : text.bodyMedium,
                // A cancelled entry is struck through as well as labelled, so
                // the state does not depend on noticing a colour.
                strutStyle: const StrutStyle(forceStrutHeight: true),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, top: 2),
          child: Row(
            children: <Widget>[
              Icon(
                _iconFor(entry.source),
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  entry.sourceLabel ?? _labelFor(l10n, entry.source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (entry.location != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    entry.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(CalendarSource source) => switch (source) {
    CalendarSource.timetable => Icons.school_outlined,
    CalendarSource.moodle => Icons.assignment_outlined,
    CalendarSource.publicCalendar => Icons.public,
  };

  static String _labelFor(AppLocalizations l10n, CalendarSource source) =>
      switch (source) {
        CalendarSource.timetable => l10n.todaySourceTimetable,
        CalendarSource.moodle => l10n.todaySourceMoodle,
        CalendarSource.publicCalendar => l10n.todaySourcePublic,
      };
}

class _AgendaLoading extends StatelessWidget {
  const _AgendaLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 20,
    child: Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
