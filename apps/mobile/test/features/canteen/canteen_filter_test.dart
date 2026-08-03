// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/domain/canteen_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Meal _meal(String name, {List<String> markers = const <String>[]}) => Meal(
  id: 'id-$name',
  name: name,
  markers: <MealMarker>[
    for (final String code in markers)
      MealMarker(code: code, label: 'label-$code', kind: 'ingredient'),
  ],
);

void main() {
  group('marker filters', () {
    test('an unfiltered list is untouched', () {
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b')];
      expect(CanteenFilter.none.apply(meals).length, 2);
      expect(CanteenFilter.none.isActive, isFalse);
    });

    test('a required marker narrows the list', () {
      final List<Meal> meals = <Meal>[
        _meal('vegan dish', markers: <String>['52']),
        _meal('other', markers: <String>['1']),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleRequired('52');

      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'vegan dish',
      ]);
      expect(filter.isActive, isTrue);
    });

    test('two required markers mean both, not either', () {
      // Picking two allergen-free markers must narrow, not widen.
      final List<Meal> meals = <Meal>[
        _meal('both', markers: <String>['52', '53']),
        _meal('only one', markers: <String>['52']),
      ];
      final CanteenFilter filter = CanteenFilter.none
          .toggleRequired('52')
          .toggleRequired('53');

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['both']);
    });

    test('an excluded marker hides a meal', () {
      final List<Meal> meals = <Meal>[
        _meal('with nuts', markers: <String>['nuts']),
        _meal('safe'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleExcluded('nuts');

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['safe']);
    });

    test('a marker cannot be required and excluded at once', () {
      // The most recent action wins; holding both would be a contradiction the
      // user could not see or resolve.
      final CanteenFilter filter = CanteenFilter.none
          .toggleExcluded('52')
          .toggleRequired('52');
      expect(filter.requiredMarkers, contains('52'));
      expect(filter.excludedMarkers, isNot(contains('52')));

      final CanteenFilter reversed = filter.toggleExcluded('52');
      expect(reversed.excludedMarkers, contains('52'));
      expect(reversed.requiredMarkers, isNot(contains('52')));
    });

    test('toggling twice returns to the start', () {
      final CanteenFilter filter = CanteenFilter.none
          .toggleRequired('52')
          .toggleRequired('52');
      expect(filter.requiredMarkers, isEmpty);
      expect(filter.isActive, isFalse);
    });
  });

  group('favourites and hidden dishes', () {
    test('favourites are keyed by name, not by the upstream id', () {
      // The source re-publishes the same dish with a new id every week; an
      // id-keyed favourite would quietly stop matching it.
      final CanteenFilter filter = CanteenFilter.none.toggleFavourite(
        _meal('Gemüsepfanne'),
      );
      final Meal sameDishNextWeek = Meal(
        id: 'a-completely-different-id',
        name: 'Gemüsepfanne',
      );
      expect(filter.isFavourite(sameDishNextWeek), isTrue);
    });

    test('a hidden dish disappears from the list', () {
      final List<Meal> meals = <Meal>[_meal('Leber'), _meal('Pasta')];
      final CanteenFilter filter = CanteenFilter.none.toggleHidden(
        _meal('Leber'),
      );
      expect(filter.apply(meals).map((Meal m) => m.name), <String>['Pasta']);
    });

    test('starring a hidden dish un-hides it', () {
      final CanteenFilter filter = CanteenFilter.none
          .toggleHidden(_meal('Pasta'))
          .toggleFavourite(_meal('Pasta'));
      expect(filter.isHidden(_meal('Pasta')), isFalse);
      expect(filter.isFavourite(_meal('Pasta')), isTrue);
    });

    test('hiding a favourite un-stars it', () {
      final CanteenFilter filter = CanteenFilter.none
          .toggleFavourite(_meal('Pasta'))
          .toggleHidden(_meal('Pasta'));
      expect(filter.isFavourite(_meal('Pasta')), isFalse);
      expect(filter.isHidden(_meal('Pasta')), isTrue);
    });

    test('favourites are listed first', () {
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b'), _meal('c')];
      final CanteenFilter filter = CanteenFilter.none.toggleFavourite(
        _meal('c'),
      );
      expect(filter.apply(meals).first.name, 'c');
    });

    test('favourites-only shows nothing else', () {
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b')];
      final CanteenFilter filter = CanteenFilter.none
          .toggleFavourite(_meal('a'))
          .withFavouritesOnly(value: true);
      expect(filter.apply(meals).map((Meal m) => m.name), <String>['a']);
    });
  });

  group('clearing', () {
    test('keeps favourites and hidden dishes', () {
      // Those are long-lived preferences, not a transient view.
      final CanteenFilter filter = CanteenFilter.none
          .toggleRequired('52')
          .toggleExcluded('nuts')
          .toggleFavourite(_meal('Pasta'))
          .toggleHidden(_meal('Leber'))
          .withFavouritesOnly(value: true);

      final CanteenFilter cleared = filter.cleared();
      expect(cleared.requiredMarkers, isEmpty);
      expect(cleared.excludedMarkers, isEmpty);
      expect(cleared.favouritesOnly, isFalse);
      expect(cleared.isFavourite(_meal('Pasta')), isTrue);
      expect(cleared.isHidden(_meal('Leber')), isTrue);
    });
  });

  group('price group', () {
    test('is null by default so the API keeps its own emphasis', () {
      expect(CanteenFilter.none.priceGroup, isNull);
    });

    test('can be set and cleared', () {
      final CanteenFilter filter = CanteenFilter.none.withPriceGroup(
        'employee',
      );
      expect(filter.priceGroup, 'employee');
      expect(filter.withPriceGroup(null).priceGroup, isNull);
    });

    test('does not filter anything out', () {
      // Every price group the API delivers stays available; the setting only
      // decides which one is emphasised.
      final List<Meal> meals = <Meal>[_meal('a')];
      expect(CanteenFilter.none.withPriceGroup('guest').apply(meals).length, 1);
    });
  });
}
