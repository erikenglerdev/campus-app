// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../data/canteen_models.dart';

/// One meal with the price of the chosen group.
///
/// There are deliberately **no meal images** — neither stored nor rendered.
///
/// Only **one** price is shown: the one for the group the reader selected. The
/// other groups are somebody else's price, and three numbers on a card mean
/// three numbers to read past every time.
class MealCard extends StatelessWidget {
  const MealCard({
    required this.meal,
    required this.priceGroup,
    this.isFavourite = false,
    this.onToggleFavourite,
    super.key,
  });

  final Meal meal;

  /// The one price group whose price this card shows.
  final String priceGroup;

  /// Whether the user starred this dish. Marked by a filled star **and** a
  /// semantic label, never by colour alone.
  ///
  /// A favourite is not a filter and does not move the dish: the list keeps the
  /// counter order, which is the order the food is served in.
  final bool isFavourite;

  final VoidCallback? onToggleFavourite;

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
            _Price(price: meal.priceFor(priceGroup)),
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

/// The price of the selected group, or a clear statement that there is none.
///
/// A missing price is never replaced by another group's: that would be a
/// different number for a different person, presented as if it were theirs.
class _Price extends StatelessWidget {
  const _Price({required this.price});

  final MealPrice? price;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;
    final MealPrice? price = this.price;

    if (price == null) {
      return Text(
        l10n.canteenPriceForGroupMissing,
        style: text.bodySmall?.copyWith(color: colors.textSecondary),
      );
    }

    final String formatted =
        MoneyFormatter.format(
          amount: price.amount,
          currencyCode: price.currency,
          locale: locale,
        ) ??
        l10n.canteenPriceMissing;

    return Semantics(
      label: l10n.canteenPriceSemanticLabel(price.label, formatted),
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              price.label,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          Text(formatted, style: text.titleSmall),
        ],
      ),
    );
  }
}
