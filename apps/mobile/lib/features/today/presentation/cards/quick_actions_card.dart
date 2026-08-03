// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/l10n.dart';
import 'dashboard_section.dart';

/// One-tap entries into the things students look up mid-day.
///
/// Actions rather than data, so this card has no loading, empty or error state
/// at all — it is always useful and always correct.
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DashboardSection(
      title: l10n.todayQuickActionsTitle,
      icon: Icons.bolt_outlined,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          _Action(
            icon: Icons.meeting_room_outlined,
            label: l10n.todayFindRoom,
            route: AppRoutes.campusMap,
          ),
          _Action(
            icon: Icons.contact_support_outlined,
            label: l10n.todayFindContact,
            route: AppRoutes.contacts,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: AppSizes.iconSmall),
      label: Text(label),
      onPressed: () => GoRouter.of(context).go(route),
    );
  }
}
