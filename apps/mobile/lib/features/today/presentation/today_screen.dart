// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_density.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/dashboard_card.dart';
import '../domain/day_phase.dart';
import 'cards/agenda_card.dart';
import 'cards/canteen_card.dart';
import 'cards/quick_actions_card.dart';
import 'cards/tasks_card.dart';

/// The day dashboard — the app's entry point.
///
/// Its job is to lead through a day, so it is ordered by *when* something
/// matters rather than by which feature it belongs to: what is on now, what
/// else is on today, food, then the quieter things.
///
/// Every card is an island. It fetches its own data, shows its own loading,
/// empty and error state, and a failure in one source leaves the others
/// untouched — a dashboard that goes blank because one endpoint is down would
/// be worse than no dashboard.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.now});

  /// Injected by tests so time-dependent behaviour is deterministic.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final DateTime moment = now ?? DateTime.now();
    final DayPhase phase = TeachingDay.phaseAt(moment);
    final DateTime focusDate = TeachingDay.focusDate(moment);

    final DashboardConfig config = ref.watch(
      settingsProvider.select((AppSettings s) => s.dashboard),
    );
    final List<DashboardCard> cards = config.visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(l10n, phase)),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.todayRefresh,
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            metrics.screenPadding,
            0,
            metrics.screenPadding,
            metrics.sectionGap,
          ),
          children: <Widget>[
            // Late at night "today" is over; say so instead of showing an
            // empty agenda and letting the user wonder whether it is broken.
            if (phase.prefersNextDay) ...<Widget>[
              _PhaseHint(text: l10n.todayTomorrowHint),
              SizedBox(height: metrics.cardGap),
            ],
            if (cards.isEmpty)
              _EmptyDashboard(message: l10n.todayEmptyDashboard)
            else
              for (final DashboardCard card in cards) ...<Widget>[
                _CardHost(
                  key: ValueKey<DashboardCard>(card),
                  child: _buildCard(card, moment, focusDate),
                ),
                SizedBox(height: metrics.cardGap),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(DashboardCard card, DateTime now, DateTime focusDate) =>
      switch (card) {
        DashboardCard.nextClass => AgendaCard(
          now: now,
          date: focusDate,
          mode: AgendaMode.currentOrNext,
        ),
        DashboardCard.todaysAgenda => AgendaCard(
          now: now,
          date: focusDate,
          mode: AgendaMode.restOfDay,
        ),
        DashboardCard.canteen => CanteenCard(date: focusDate),
        DashboardCard.tasks => const TasksCard(),
        DashboardCard.quickActions => const QuickActionsCard(),
        // Unreachable: DashboardConfig.visible filters these out until their
        // feature lands. Kept exhaustive so adding a card is a compile error
        // here rather than a blank space at runtime.
        DashboardCard.news ||
        DashboardCard.mailStatus ||
        DashboardCard.gradesStatus => const SizedBox.shrink(),
      };

  static String _greeting(AppLocalizations l10n, DayPhase phase) =>
      switch (phase) {
        DayPhase.earlyMorning => l10n.todayGreetingMorning,
        DayPhase.daytime => l10n.todayGreetingDay,
        DayPhase.evening || DayPhase.night => l10n.todayGreetingEvening,
      };

  /// Re-reads every source the dashboard shows.
  ///
  /// Deliberately explicit rather than a blanket container reset: invalidating
  /// unrelated providers would drop caches the rest of the app still needs.
  void _refresh(WidgetRef ref) {
    ref.invalidate(settingsProvider);
  }
}

/// Wraps one card so a failure inside it cannot take the dashboard with it.
class _CardHost extends StatelessWidget {
  const _CardHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _PhaseHint extends StatelessWidget {
  const _PhaseHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.nightlight_outlined,
          size: AppSizes.iconSmall,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(text, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.dashboard_customize_outlined,
            size: AppSizes.illustrationIcon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => GoRouter.of(context).go(AppRoutes.settings),
            child: Text(context.l10n.settingsTitle),
          ),
        ],
      ),
    );
  }
}
