// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/canteen_models.dart';
import '../domain/canteen_filter.dart';

/// Owns the locally stored canteen preferences.
///
/// Everything here stays on the device: which markers to require or avoid is
/// close to health information, and there is neither an account to sync it to
/// nor a reason to send it anywhere.
class CanteenFilterController extends Notifier<CanteenFilter> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  @override
  CanteenFilter build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    Set<String> list(String key) =>
        (store.getStringList(key) ?? const <String>[]).toSet();
    return CanteenFilter(
      requiredMarkers: list(PreferenceKeys.canteenRequiredMarkers),
      excludedMarkers: list(PreferenceKeys.canteenExcludedMarkers),
      priceGroup: store.getString(PreferenceKeys.canteenPriceGroup),
      favourites: list(PreferenceKeys.canteenFavourites),
      hidden: list(PreferenceKeys.canteenHidden),
      favouritesOnly: store.getInt(PreferenceKeys.canteenFavouritesOnly) == 1,
    );
  }

  Future<void> toggleRequired(String code) =>
      _write(state.toggleRequired(code));

  Future<void> toggleExcluded(String code) =>
      _write(state.toggleExcluded(code));

  Future<void> toggleFavourite(Meal meal) =>
      _write(state.toggleFavourite(meal));

  Future<void> toggleHidden(Meal meal) => _write(state.toggleHidden(meal));

  Future<void> setPriceGroup(String? group) =>
      _write(state.withPriceGroup(group));

  Future<void> setFavouritesOnly({required bool value}) =>
      _write(state.withFavouritesOnly(value: value));

  Future<void> clear() => _write(state.cleared());

  Future<void> _write(CanteenFilter next) async {
    state = next;
    final KeyValueStore store = _store;
    // Sorted so an unchanged selection does not rewrite the store in a new
    // order on every launch.
    Future<void> put(String key, Set<String> values) =>
        store.setStringList(key, values.toList(growable: false)..sort());
    await put(PreferenceKeys.canteenRequiredMarkers, next.requiredMarkers);
    await put(PreferenceKeys.canteenExcludedMarkers, next.excludedMarkers);
    await put(PreferenceKeys.canteenFavourites, next.favourites);
    await put(PreferenceKeys.canteenHidden, next.hidden);
    await store.setInt(
      PreferenceKeys.canteenFavouritesOnly,
      next.favouritesOnly ? 1 : 0,
    );
    final String? group = next.priceGroup;
    if (group == null) {
      await store.remove(PreferenceKeys.canteenPriceGroup);
    } else {
      await store.setString(PreferenceKeys.canteenPriceGroup, group);
    }
  }
}

final NotifierProvider<CanteenFilterController, CanteenFilter>
canteenFilterProvider =
    NotifierProvider<CanteenFilterController, CanteenFilter>(
      CanteenFilterController.new,
    );
