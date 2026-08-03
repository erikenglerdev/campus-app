// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/network/loaded.dart';
import '../../../../l10n/l10n.dart';
import '../../../canteen/application/canteen_providers.dart';
import '../../../canteen/data/canteen_models.dart';
import 'dashboard_section.dart';

/// The canteen offer for the day the dashboard is describing.
///
/// Reads the cached two-week menu window and picks the day itself, so it is
/// independent of whichever day the canteen screen happens to be showing — a
/// dashboard that changed because the user browsed elsewhere would be a bug.
class CanteenCard extends ConsumerWidget {
  const CanteenCard({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? slug = ref.watch(selectedCanteenSlugProvider);

    // No canteen configured yet is a normal state, not an error.
    if (slug == null) return const SizedBox.shrink();

    final AsyncValue<Loaded<CanteenMenu>> menu = ref.watch(
      canteenMenuProvider(slug),
    );

    return DashboardSection(
      title: l10n.todayCanteenTitle,
      icon: Icons.restaurant_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.canteen),
      child: switch (menu) {
        AsyncError<Loaded<CanteenMenu>>() => const DashboardCardError(),
        AsyncData<Loaded<CanteenMenu>>(:final Loaded<CanteenMenu> value) =>
          _Offer(day: value.value.dayFor(date)),
        _ => const _Loading(),
      },
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({required this.day});

  final MenuDay? day;

  @override
  Widget build(BuildContext context) {
    final MenuDay? menuDay = day;
    if (menuDay == null || menuDay.meals.isEmpty) {
      return DashboardLine(context.l10n.canteenNoMealsMessage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A short preview, not the whole menu — the canteen screen is one tap
        // away and shows everything.
        for (final Meal meal in menuDay.meals.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              meal.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

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
