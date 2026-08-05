// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../data/canteen_models.dart';
import 'meal_taxonomy.dart';

/// The user's local canteen preferences.
///
/// Everything here stays on the device. Which allergens somebody avoids is
/// close to health information: it is never sent to a backend, never logged and
/// never used for anything but deciding what this screen shows.
///
/// The filter works on the API's **stable semantic keys**, not on the source's
/// marker codes or its German labels — see [MealTrait] and [MealAllergen] for
/// why that distinction matters on food.
@immutable
class CanteenFilter {
  const CanteenFilter({
    this.requiredTraits = const <MealTrait>{},
    this.excludedAllergens = const <MealAllergen>{},
    this.priceGroup = MealPrice.studentGroup,
    this.favourites = const <String>{},
  });

  /// Properties a dish must have. **All** of them, not any: picking two
  /// narrows the list, it does not widen it.
  final Set<MealTrait> requiredTraits;

  /// Allergens that hide a dish.
  ///
  /// Excluding a parent facet covers its subtypes automatically, because the
  /// API delivers the parent alongside every subtype. Excluding one subtype on
  /// its own excludes exactly that subtype — a dish declared only as "contains
  /// gluten" is not evidence of wheat.
  final Set<MealAllergen> excludedAllergens;

  /// The one price group whose price is shown. Never null: a card shows exactly
  /// one price, and "student" is the group most readers of this app are in.
  final String priceGroup;

  /// Meal names the user starred. Keyed by **name**, not by id: the upstream id
  /// changes every time a dish is re-published, so an id-keyed favourite would
  /// silently stop matching the same dish next week.
  ///
  /// Favourites are not a filter and do not reorder anything. They are kept so
  /// the app can offer notifications for them later.
  final Set<String> favourites;

  static const CanteenFilter none = CanteenFilter();

  bool get isActive =>
      requiredTraits.isNotEmpty || excludedAllergens.isNotEmpty;

  bool isFavourite(Meal meal) => favourites.contains(meal.name);

  /// Whether [meal] survives the filter.
  bool allows(Meal meal) {
    if (meal.allergens.any(excludedAllergens.contains)) return false;
    return requiredTraits.every(meal.traits.contains);
  }

  /// Applies the filter, keeping the source's order.
  ///
  /// The counter order is the order the food is served in; re-sorting by
  /// favourites would make the list stop matching the board on the wall.
  List<Meal> apply(Iterable<Meal> meals) =>
      List<Meal>.unmodifiable(meals.where(allows));

  CanteenFilter toggleTrait(MealTrait trait) =>
      copyWith(requiredTraits: _toggled(requiredTraits, trait));

  CanteenFilter toggleAllergen(MealAllergen allergen) =>
      copyWith(excludedAllergens: _toggled(excludedAllergens, allergen));

  CanteenFilter toggleFavourite(Meal meal) =>
      copyWith(favourites: _toggled(favourites, meal.name));

  CanteenFilter withPriceGroup(String group) => copyWith(priceGroup: group);

  /// Clears the narrowing filters but keeps favourites and the price group —
  /// those are long-lived preferences, not a transient view.
  CanteenFilter cleared() =>
      CanteenFilter(priceGroup: priceGroup, favourites: favourites);

  CanteenFilter copyWith({
    Set<MealTrait>? requiredTraits,
    Set<MealAllergen>? excludedAllergens,
    String? priceGroup,
    Set<String>? favourites,
  }) => CanteenFilter(
    requiredTraits: requiredTraits ?? this.requiredTraits,
    excludedAllergens: excludedAllergens ?? this.excludedAllergens,
    priceGroup: priceGroup ?? this.priceGroup,
    favourites: favourites ?? this.favourites,
  );

  static Set<T> _toggled<T>(Set<T> set, T value) {
    final Set<T> next = set.toSet();
    if (!next.remove(value)) next.add(value);
    return next;
  }

  @override
  bool operator ==(Object other) =>
      other is CanteenFilter &&
      setEquals(other.requiredTraits, requiredTraits) &&
      setEquals(other.excludedAllergens, excludedAllergens) &&
      other.priceGroup == priceGroup &&
      setEquals(other.favourites, favourites);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(requiredTraits),
    Object.hashAllUnordered(excludedAllergens),
    priceGroup,
    Object.hashAllUnordered(favourites),
  );
}
