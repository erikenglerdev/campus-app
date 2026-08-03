// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../../core/theme/app_density.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/l10n.dart';

/// The shared frame of a dashboard card.
///
/// One frame for every card so the dashboard reads as a single surface rather
/// than a pile of differently-shaped panels — and so a card only has to supply
/// its content, never its chrome.
///
/// Cards are deliberately flat: a heading, a hairline border and the content.
/// Nesting cards inside cards is what makes a dashboard look busy.
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppMetrics metrics = context.metrics;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Widget content = Padding(
      padding: EdgeInsets.all(metrics.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: AppSizes.iconSmall, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              ?trailing,
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconSmall,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// What a card shows when its own source failed.
///
/// Scoped to the card on purpose: one broken source must not blank the
/// dashboard, and the user should still see which part is missing.
class DashboardCardError extends StatelessWidget {
  const DashboardCardError({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(
          Icons.cloud_off_outlined,
          size: AppSizes.iconSmall,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            context.l10n.todayCardFailed,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A short, quiet line of body copy — the usual content of a card.
class DashboardLine extends StatelessWidget {
  const DashboardLine(this.text, {this.emphasised = false, super.key});

  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Text(
      text,
      style: emphasised ? textTheme.titleMedium : textTheme.bodyMedium,
    );
  }
}
