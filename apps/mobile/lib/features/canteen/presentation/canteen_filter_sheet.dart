// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../application/canteen_filter_controller.dart';
import '../data/canteen_models.dart';
import '../domain/canteen_filter.dart';

/// Filter sheet for the canteen.
///
/// The marker list is built from **the markings the source actually published
/// for the visible days**, not from a hardcoded vocabulary. That is the whole
/// point: the app never offers a filter it cannot honour, and a marking that
/// disappears upstream disappears here instead of silently matching nothing.
Future<void> showCanteenFilterSheet(
  BuildContext context,
  List<MealMarker> availableMarkers,
  List<MealPrice> availablePrices,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext _) =>
        _CanteenFilterSheet(markers: availableMarkers, prices: availablePrices),
  );
}

class _CanteenFilterSheet extends ConsumerWidget {
  const _CanteenFilterSheet({required this.markers, required this.prices});

  final List<MealMarker> markers;
  final List<MealPrice> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CanteenFilter filter = ref.watch(canteenFilterProvider);
    final CanteenFilterController controller = ref.read(
      canteenFilterProvider.notifier,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: SheetBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.canteenFilterTitle, style: text.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.md),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.canteenFilterFavouritesOnly),
              value: filter.favouritesOnly,
              onChanged: (bool value) =>
                  controller.setFavouritesOnly(value: value),
            ),

            const Divider(),
            Text(l10n.canteenFilterRequire, style: text.titleSmall),
            Text(l10n.canteenFilterMarkersHint, style: text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (markers.isEmpty)
              Text(l10n.canteenFilterNoMarkers, style: text.bodyMedium)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final MealMarker marker in markers)
                    FilterChip(
                      label: Text(marker.label),
                      selected: filter.requiredMarkers.contains(marker.code),
                      onSelected: (_) => controller.toggleRequired(marker.code),
                    ),
                ],
              ),

            if (markers.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.canteenFilterExclude, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final MealMarker marker in markers)
                    FilterChip(
                      avatar: filter.excludedMarkers.contains(marker.code)
                          ? const Icon(Icons.block, size: AppSizes.iconSmall)
                          : null,
                      label: Text(marker.label),
                      selected: filter.excludedMarkers.contains(marker.code),
                      onSelected: (_) => controller.toggleExcluded(marker.code),
                    ),
                ],
              ),
            ],

            if (prices.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.canteenPriceGroupLabel, style: text.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              // Every group the API delivers stays visible on the card; this
              // only decides which one is emphasised.
              RadioGroup<String?>(
                groupValue: filter.priceGroup,
                onChanged: controller.setPriceGroup,
                child: Column(
                  children: <Widget>[
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      value: null,
                      title: Text(l10n.canteenPriceGroupDefault),
                    ),
                    for (final MealPrice price in prices)
                      RadioListTile<String?>(
                        contentPadding: EdgeInsets.zero,
                        value: price.group,
                        title: Text(price.label),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: filter.isActive ? controller.clear : null,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l10n.canteenFilterClear),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
