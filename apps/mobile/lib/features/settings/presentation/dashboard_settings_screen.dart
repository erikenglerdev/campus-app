// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/settings_controller.dart';
import '../../../l10n/l10n.dart';
import '../../today/domain/dashboard_card.dart';

/// Order and visibility of the day dashboard's cards.
///
/// Reordering uses explicit up/down actions rather than only drag handles:
/// dragging is not reachable with a screen reader or a switch control, and the
/// order is a real setting, not a flourish.
///
/// Cards whose feature is not built yet are listed but marked, so the order a
/// user sets now still applies once they land — and nobody wonders why a card
/// they enabled never appears.
class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DashboardConfig config = ref.watch(
      settingsProvider.select((AppSettings s) => s.dashboard),
    );
    final List<DashboardCard> cards = config.configurable;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDashboard)),
      body: ListView(
        children: <Widget>[
          for (int i = 0; i < cards.length; i++)
            _CardRow(
              card: cards[i],
              index: i,
              total: cards.length,
              visible: config.isVisible(cards[i]),
              onToggle: (bool value) => ref
                  .read(settingsProvider.notifier)
                  .setDashboard(
                    config.withVisibility(cards[i], visible: value),
                  ),
              onMove: (int delta) => ref
                  .read(settingsProvider.notifier)
                  .setDashboard(config.reordered(cards[i], i + delta)),
            ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.index,
    required this.total,
    required this.visible,
    required this.onToggle,
    required this.onMove,
  });

  final DashboardCard card;
  final int index;
  final int total;
  final bool visible;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    // The move buttons sit beside the switch, not stacked in the leading slot:
    // two stacked icon buttons are taller than a list row is allowed to be.
    return ListTile(
      title: Text(dashboardCardLabel(l10n, card)),
      subtitle: card.isImplemented ? null : Text(l10n.settingsDashboardPending),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: l10n.settingsCardMoveUp,
            visualDensity: VisualDensity.compact,
            onPressed: index == 0 ? null : () => onMove(-1),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: l10n.settingsCardMoveDown,
            visualDensity: VisualDensity.compact,
            onPressed: index == total - 1 ? null : () => onMove(1),
          ),
          Switch(value: visible, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// Localised name of a dashboard card.
String dashboardCardLabel(AppLocalizations l10n, DashboardCard card) =>
    switch (card) {
      DashboardCard.nextClass => l10n.todayNextLabel,
      DashboardCard.todaysAgenda => l10n.todayAgendaTitle,
      DashboardCard.canteen => l10n.todayCanteenTitle,
      DashboardCard.news => l10n.navNews,
      DashboardCard.tasks => l10n.todayTasksTitle,
      DashboardCard.mailStatus => l10n.mailTitle,
      DashboardCard.gradesStatus => l10n.gradesTitle,
      DashboardCard.quickActions => l10n.todayQuickActionsTitle,
    };
