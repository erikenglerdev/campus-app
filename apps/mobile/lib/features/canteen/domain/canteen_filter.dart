// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../data/canteen_models.dart';

/// The user's local canteen preferences.
///
/// ## Why there is no "vegetarian" switch
///
/// The upstream source does not state a diet. It delivers a dictionary of
/// numeric marker codes with German labels — `52` happens to be `vegan` today
/// — and nothing that says "this meal is vegetarian". Deriving one from those
/// codes would mean hardcoding a foreign key list and hoping it never changes.
///
/// On food that is not a cosmetic risk: someone avoiding pork or eating vegan
/// would be trusting a label the app invented. So the filter works on the
/// markers the source actually publishes: require some, exclude others, by
/// their own codes and their own labels. If the source publishes `vegan`, the
/// user can require it — and if it stops, the filter disappears with it rather
/// than silently lying.
///
/// A curated diet flag would be a **backend** decision (a reviewed mapping in
/// `IngredientDefinition`), not something the client may improvise.
@immutable
class CanteenFilter {
  const CanteenFilter({
    this.requiredMarkers = const <String>{},
    this.excludedMarkers = const <String>{},
    this.priceGroup,
    this.favourites = const <String>{},
    this.hidden = const <String>{},
    this.favouritesOnly = false,
  });

  /// Marker codes a meal must carry to be shown.
  final Set<String> requiredMarkers;

  /// Marker codes that hide a meal — allergens and ingredients to avoid.
  final Set<String> excludedMarkers;

  /// The price group to emphasise, or `null` for the API's own emphasis
  /// (the student price).
  final String? priceGroup;

  /// Meal names the user starred. Keyed by **name**, not by id: the upstream
  /// id changes every time a dish is re-published, so an id-keyed favourite
  /// would silently stop matching the same dish next week.
  final Set<String> favourites;

  /// Meal names the user never wants to see.
  final Set<String> hidden;

  final bool favouritesOnly;

  static const CanteenFilter none = CanteenFilter();

  bool get isActive =>
      requiredMarkers.isNotEmpty ||
      excludedMarkers.isNotEmpty ||
      hidden.isNotEmpty ||
      favouritesOnly;

  bool isFavourite(Meal meal) => favourites.contains(meal.name);

  bool isHidden(Meal meal) => hidden.contains(meal.name);

  /// Whether [meal] survives the filter.
  bool allows(Meal meal) {
    if (isHidden(meal)) return false;
    if (favouritesOnly && !isFavourite(meal)) return false;

    final Set<String> codes = meal.markers
        .map((MealMarker marker) => marker.code)
        .toSet();
    if (excludedMarkers.any(codes.contains)) return false;
    // "Required" means all of them, not any: picking two allergen-free markers
    // should narrow the list, not widen it.
    if (!requiredMarkers.every(codes.contains)) return false;
    return true;
  }

  /// Applies the filter, favourites first so a starred dish is easy to find.
  List<Meal> apply(Iterable<Meal> meals) {
    final List<Meal> kept = meals.where(allows).toList();
    kept.sort((Meal a, Meal b) {
      final bool fa = isFavourite(a);
      final bool fb = isFavourite(b);
      if (fa != fb) return fa ? -1 : 1;
      return 0;
    });
    return List<Meal>.unmodifiable(kept);
  }

  CanteenFilter toggleRequired(String code) => copyWith(
    requiredMarkers: _toggled(requiredMarkers, code),
    // A marker cannot be required and excluded at once; requiring wins,
    // because that is the action the user just took.
    excludedMarkers: excludedMarkers.where((String c) => c != code).toSet(),
  );

  CanteenFilter toggleExcluded(String code) => copyWith(
    excludedMarkers: _toggled(excludedMarkers, code),
    requiredMarkers: requiredMarkers.where((String c) => c != code).toSet(),
  );

  CanteenFilter toggleFavourite(Meal meal) => copyWith(
    favourites: _toggled(favourites, meal.name),
    // Starring something that was hidden un-hides it; the two would otherwise
    // contradict each other.
    hidden: hidden.where((String n) => n != meal.name).toSet(),
  );

  CanteenFilter toggleHidden(Meal meal) => copyWith(
    hidden: _toggled(hidden, meal.name),
    favourites: favourites.where((String n) => n != meal.name).toSet(),
  );

  CanteenFilter withPriceGroup(String? group) =>
      copyWith(priceGroup: group, clearPriceGroup: group == null);

  CanteenFilter withFavouritesOnly({required bool value}) =>
      copyWith(favouritesOnly: value);

  /// Clears the narrowing filters but keeps favourites and hidden dishes —
  /// those are long-lived preferences, not a transient view.
  CanteenFilter cleared() => CanteenFilter(
    favourites: favourites,
    hidden: hidden,
    priceGroup: priceGroup,
  );

  CanteenFilter copyWith({
    Set<String>? requiredMarkers,
    Set<String>? excludedMarkers,
    String? priceGroup,
    bool clearPriceGroup = false,
    Set<String>? favourites,
    Set<String>? hidden,
    bool? favouritesOnly,
  }) => CanteenFilter(
    requiredMarkers: requiredMarkers ?? this.requiredMarkers,
    excludedMarkers: excludedMarkers ?? this.excludedMarkers,
    priceGroup: clearPriceGroup ? null : (priceGroup ?? this.priceGroup),
    favourites: favourites ?? this.favourites,
    hidden: hidden ?? this.hidden,
    favouritesOnly: favouritesOnly ?? this.favouritesOnly,
  );

  static Set<String> _toggled(Set<String> set, String value) {
    final Set<String> next = set.toSet();
    if (!next.remove(value)) next.add(value);
    return next;
  }

  @override
  bool operator ==(Object other) =>
      other is CanteenFilter &&
      setEquals(other.requiredMarkers, requiredMarkers) &&
      setEquals(other.excludedMarkers, excludedMarkers) &&
      other.priceGroup == priceGroup &&
      setEquals(other.favourites, favourites) &&
      setEquals(other.hidden, hidden) &&
      other.favouritesOnly == favouritesOnly;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(requiredMarkers),
    Object.hashAllUnordered(excludedMarkers),
    priceGroup,
    Object.hashAllUnordered(favourites),
    Object.hashAllUnordered(hidden),
    favouritesOnly,
  );
}
