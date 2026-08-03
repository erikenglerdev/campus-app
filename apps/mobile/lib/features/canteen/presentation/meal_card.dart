// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../data/canteen_models.dart';

/// One meal with all of its price groups.
///
/// There are deliberately **no meal images** — neither stored nor rendered.
/// The student price group is emphasised typographically *and* with an icon, so
/// the emphasis survives greyscale and colour blindness.
class MealCard extends StatelessWidget {
  const MealCard({
    required this.meal,
    this.isFavourite = false,
    this.emphasisedPriceGroup,
    this.onToggleFavourite,
    this.onHide,
    super.key,
  });

  final Meal meal;

  /// Whether the user starred this dish. Marked by a filled star **and** a
  /// semantic label, never by colour alone.
  final bool isFavourite;

  /// Price group the user asked to emphasise, or `null` to keep the API's own
  /// emphasis. Every delivered group stays visible either way.
  final String? emphasisedPriceGroup;

  final VoidCallback? onToggleFavourite;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (meal.isSprint)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Semantics(
                  label: l10n.canteenSprintSemanticLabel,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.bolt_outlined,
                        size: AppSpacing.lg,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.canteenSprintLabel,
                        style: text.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    label: isFavourite
                        ? '${l10n.canteenFavouriteSemantic}. ${meal.name}'
                        : meal.name,
                    child: Text(meal.name, style: text.titleMedium),
                  ),
                ),
                if (onToggleFavourite != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isFavourite
                        ? l10n.canteenFavouriteRemove
                        : l10n.canteenFavouriteAdd,
                    onPressed: onToggleFavourite,
                    icon: Icon(isFavourite ? Icons.star : Icons.star_border),
                  ),
                if (onHide != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.canteenHideMeal,
                    onPressed: onHide,
                    icon: const Icon(Icons.visibility_off_outlined),
                  ),
              ],
            ),
            if (meal.subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                meal.subtitle!,
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ],
            if (meal.extras.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _LabelledWrap(
                label: l10n.canteenExtrasLabel,
                values: meal.extras,
              ),
            ],
            if (meal.nonIngredientMarkers.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _LabelledWrap(
                label: l10n.canteenMarkersLabel,
                values: meal.nonIngredientMarkers
                    .map((MealMarker marker) => marker.label)
                    .toList(growable: false),
              ),
            ],
            if (meal.ingredients.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _LabelledWrap(
                label: l10n.canteenIngredientsLabel,
                values: meal.ingredients
                    .map((MealMarker marker) => marker.label)
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _PriceList(
              prices: meal.orderedPrices,
              emphasisedGroup: emphasisedPriceGroup,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelledWrap extends StatelessWidget {
  const _LabelledWrap({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final String value in values)
              Chip(
                label: Text(value),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }
}

/// Renders **every** price group the API delivered. Nothing is estimated and
/// nothing is hidden; a missing group simply does not appear.
class _PriceList extends StatelessWidget {
  const _PriceList({required this.prices, this.emphasisedGroup});

  final List<MealPrice> prices;

  /// Which group to highlight, or `null` for the API's own emphasis.
  final String? emphasisedGroup;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    if (prices.isEmpty) {
      return Text(l10n.canteenPriceMissing, style: text.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.canteenPricesLabel, style: text.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final MealPrice price in prices)
          Builder(
            builder: (BuildContext context) {
              final String formatted =
                  MoneyFormatter.format(
                    amount: price.amount,
                    currencyCode: price.currency,
                    locale: locale,
                  ) ??
                  l10n.canteenPriceMissing;
              // The API emphasises the student price; a user who is not a
              // student can point the emphasis at their own group. Every group
              // stays listed either way — the setting changes what is
              // highlighted, never what is available.
              final bool emphasised = emphasisedGroup == null
                  ? price.isStudentGroup
                  : price.group == emphasisedGroup;
              return Semantics(
                label: emphasised
                    ? l10n.canteenPriceStudentSemanticLabel(
                        price.label,
                        formatted,
                      )
                    : l10n.canteenPriceSemanticLabel(price.label, formatted),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(
                    children: <Widget>[
                      if (emphasised) ...<Widget>[
                        Icon(
                          Icons.star_outline,
                          size: AppSpacing.lg,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ] else
                        const SizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: Text(
                          price.label,
                          style: emphasised
                              ? text.titleSmall?.copyWith(color: colors.primary)
                              : text.bodyMedium,
                        ),
                      ),
                      Text(
                        formatted,
                        style: emphasised
                            ? text.titleSmall?.copyWith(color: colors.primary)
                            : text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
