// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/canteen/application/canteen_filter_controller.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/domain/canteen_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a fresh install has no filter at all', () {
    final CanteenFilter filter = _container(
      InMemoryKeyValueStore(),
    ).read(canteenFilterProvider);
    expect(filter, CanteenFilter.none);
    expect(filter.isActive, isFalse);
  });

  test('every part of the filter survives a restart', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleRequired('52');
    await controller.toggleExcluded('nuts');
    await controller.setPriceGroup('employee');
    await controller.toggleFavourite(const Meal(id: 'x', name: 'Gemüsepfanne'));
    await controller.toggleHidden(const Meal(id: 'y', name: 'Leber'));
    await controller.setFavouritesOnly(value: true);

    final CanteenFilter reloaded = _container(
      store,
    ).read(canteenFilterProvider);
    expect(reloaded.requiredMarkers, <String>{'52'});
    expect(reloaded.excludedMarkers, <String>{'nuts'});
    expect(reloaded.priceGroup, 'employee');
    expect(reloaded.favourites, <String>{'Gemüsepfanne'});
    expect(reloaded.hidden, <String>{'Leber'});
    expect(reloaded.favouritesOnly, isTrue);
  });

  test('clearing the price group removes the key', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.setPriceGroup('guest');
    await controller.setPriceGroup(null);

    expect(store.getString(PreferenceKeys.canteenPriceGroup), isNull);
    expect(_container(store).read(canteenFilterProvider).priceGroup, isNull);
  });

  test('sets are written in a stable order', () async {
    // Otherwise an unchanged selection would rewrite the store in a new order
    // on every launch.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleExcluded('c');
    await controller.toggleExcluded('a');
    await controller.toggleExcluded('b');

    expect(store.getStringList(PreferenceKeys.canteenExcludedMarkers), <String>[
      'a',
      'b',
      'c',
    ]);
  });

  test('clearing keeps favourites and hidden dishes on disk', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleRequired('52');
    await controller.toggleFavourite(const Meal(id: 'x', name: 'Pasta'));
    await controller.clear();

    expect(store.getStringList(PreferenceKeys.canteenRequiredMarkers), isEmpty);
    expect(store.getStringList(PreferenceKeys.canteenFavourites), <String>[
      'Pasta',
    ]);
  });
}
