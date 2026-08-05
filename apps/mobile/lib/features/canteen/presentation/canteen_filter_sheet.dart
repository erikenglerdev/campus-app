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
import '../domain/meal_taxonomy.dart';
import 'meal_taxonomy_labels.dart';

/// Filter sheet for the canteen.
///
/// The vocabulary is **fixed**, not built from the visible day. A filter that
/// appears and disappears with the day's offer cannot be relied on, and "no
/// peanuts" has to mean the same thing on a Tuesday as on a Friday. It is also
/// the API's own taxonomy rather than the source's marker codes — see
/// [MealAllergen].
///
/// Nothing selected here leaves the device.
Future<void> showCanteenFilterSheet(
  BuildContext context,
  List<MealPrice> availablePrices,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext _) => _CanteenFilterSheet(prices: availablePrices),
  );
}

class _CanteenFilterSheet extends ConsumerWidget {
  const _CanteenFilterSheet({required this.prices});

  /// The price groups the API delivered, so the choice cannot offer a group
  /// this canteen does not have.
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

            Semantics(
              header: true,
              child: Text(
                l10n.canteenFilterMustContain,
                style: text.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final MealTrait trait in MealTrait.values)
                  FilterChip(
                    label: Text(mealTraitLabel(l10n, trait)),
                    selected: filter.requiredTraits.contains(trait),
                    onSelected: (_) => controller.toggleTrait(trait),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.canteenFilterMustNotContain,
                style: text.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final MealAllergen allergen in allergenTopLevel)
              _AllergenTile(
                allergen: allergen,
                filter: filter,
                controller: controller,
              ),

            if (prices.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.canteenPriceGroupSection,
                  style: text.titleSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Exactly one group: a card shows one price, for one person.
              RadioGroup<String>(
                groupValue: filter.priceGroup,
                onChanged: (String? group) {
                  if (group != null) controller.setPriceGroup(group);
                },
                child: Column(
                  children: <Widget>[
                    for (final MealPrice price in prices)
                      RadioListTile<String>(
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

/// One allergen, with its subtypes underneath when it has any.
///
/// The parent is not a "select all" switch: ticking it excludes every dish the
/// source declared for the facet, including those that only name a subtype,
/// because the API delivers the parent alongside each subtype. Ticking one
/// subtype on its own excludes exactly that one — a dish declared merely as
/// "contains gluten" is not evidence of wheat.
class _AllergenTile extends StatelessWidget {
  const _AllergenTile({
    required this.allergen,
    required this.filter,
    required this.controller,
  });

  final MealAllergen allergen;
  final CanteenFilter filter;
  final CanteenFilterController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<MealAllergen> subtypes = subtypesOf(allergen);

    Widget tile(MealAllergen value, {bool indented = false}) {
      final bool excluded = filter.excludedAllergens.contains(value);
      return CheckboxListTile(
        contentPadding: EdgeInsets.only(
          left: indented ? AppSpacing.xl : 0,
          right: 0,
        ),
        value: excluded,
        // A check mark and the word, never a colour on its own.
        title: Text(mealAllergenLabel(l10n, value)),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (_) => controller.toggleAllergen(value),
      );
    }

    if (subtypes.isEmpty) return tile(allergen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        tile(allergen),
        for (final MealAllergen subtype in subtypes)
          tile(subtype, indented: true),
      ],
    );
  }
}
