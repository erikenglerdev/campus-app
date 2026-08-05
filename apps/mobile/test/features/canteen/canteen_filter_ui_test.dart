// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/canteen/application/canteen_filter_controller.dart';
import 'package:campus_koethen/features/canteen/presentation/canteen_screen.dart';
import 'package:campus_koethen/features/canteen/presentation/meal_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

String _today() {
  final DateTime now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _meal(
  String id,
  String name, {
  List<String> traits = const <String>[],
  List<String> allergens = const <String>[],
  List<Map<String, dynamic>> prices = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'subtitle': null,
  'sourceLanguage': 'de',
  'isSprint': false,
  'extras': <String>[],
  'markers': <Map<String, dynamic>>[],
  'traits': traits,
  'allergens': allergens,
  'prices': prices.isEmpty ? _bothPrices : prices,
};

const List<Map<String, dynamic>> _bothPrices = <Map<String, dynamic>>[
  <String, dynamic>{
    'group': 'student',
    'label': 'Studierende',
    'amount': '1.95',
    'currency': 'EUR',
  },
  <String, dynamic>{
    'group': 'employee',
    'label': 'Beschäftigte',
    'amount': '4.95',
    'currency': 'EUR',
  },
];

ApiClient _api(List<Map<String, dynamic>> meals) => fakeApiClient(
  FakeHttpAdapter((RequestOptions options) {
    if (options.path.contains('/canteens/')) {
      return FakeHttpResponse(
        envelope(
          <String, dynamic>{
            'canteen': <String, dynamic>{
              'slug': 'mensa',
              'displayName': 'Mensa Köthen',
              'campusLabel': null,
            },
            'days': <Map<String, dynamic>>[
              <String, dynamic>{'date': _today(), 'meals': meals},
            ],
          },
          meta: <String, dynamic>{'dataStale': false},
        ),
      );
    }
    if (options.path.contains('/canteens')) {
      return FakeHttpResponse(
        envelope(<Map<String, dynamic>>[
          <String, dynamic>{
            'slug': 'mensa',
            'displayName': 'Mensa Köthen',
            'sortOrder': 10,
          },
        ]),
      );
    }
    return FakeHttpResponse(envelope(<Object>[]));
  }),
);

Future<ProviderContainer> pumpCanteen(
  WidgetTester tester, {
  List<Map<String, dynamic>>? meals,
  KeyValueStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = await pumpScreen(
    tester,
    const CanteenScreen(),
    locale: locale,
    keyValueStore: store,
    overrides: <Override>[
      apiClientProvider.overrideWithValue(
        _api(
          meals ??
              <Map<String, dynamic>>[
                _meal('1', 'Gemüsepfanne', traits: <String>['vegan']),
                _meal('2', 'Schnitzel'),
              ],
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('starts with the canteen and its two buttons, no app bar', (
    WidgetTester tester,
  ) async {
    await pumpCanteen(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Mensa Köthen'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Mensa wählen'), findsOneWidget);
    expect(find.text('Gemüsepfanne'), findsOneWidget);
    expect(find.text('Schnitzel'), findsOneWidget);
  });

  group('the fixed taxonomy', () {
    testWidgets('offers the four traits whatever the day holds', (
      WidgetTester tester,
    ) async {
      // A filter that appears and disappears with the day's offer cannot be
      // relied on. "Vegan" has to be there on a day without a vegan dish too.
      await pumpCanteen(
        tester,
        meals: <Map<String, dynamic>>[_meal('1', 'Schnitzel')],
      );

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Vegetarisch'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Vegan'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Fleischlos'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Sprintmenü'), findsOneWidget);
    });

    testWidgets('shows the allergen subtypes under their parent', (
      WidgetTester tester,
    ) async {
      await pumpCanteen(tester);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Enthält glutenhaltige Getreide'), findsOneWidget);
      expect(find.text('Weizen'), findsOneWidget);
      expect(find.text('Dinkel'), findsOneWidget);
      expect(find.text('Enthält Schalenfrüchte'), findsOneWidget);
      expect(find.text('Macadamianuss'), findsOneWidget);
    });

    testWidgets('a trait selected in the sheet narrows the list', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await pumpCanteen(tester, store: store);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Vegan'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Gemüsepfanne'), findsOneWidget);
      expect(find.text('Schnitzel'), findsNothing);
      expect(find.text('Filter aktiv'), findsOneWidget);
      expect(store.getStringList(PreferenceKeys.canteenTraits), <String>[
        'vegan',
      ]);
    });
  });

  testWidgets('excluding a parent allergen hides a dish declared by subtype', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.canteenAllergens: <String>['gluten'],
    });

    await pumpCanteen(
      tester,
      store: store,
      meals: <Map<String, dynamic>>[
        _meal('1', 'Nudeln', allergens: <String>['gluten', 'gluten_wheat']),
        _meal('2', 'Reis'),
      ],
    );

    expect(find.text('Nudeln'), findsNothing);
    expect(find.text('Reis'), findsOneWidget);
  });

  testWidgets('a filter that matches nothing offers a way out', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.canteenTraits: <String>['vegan'],
    });

    await pumpCanteen(
      tester,
      store: store,
      meals: <Map<String, dynamic>>[_meal('1', 'Schnitzel')],
    );

    // Different from "nothing on offer", and this one has a remedy.
    expect(find.text('Kein Gericht passt zu deinem Filter.'), findsOneWidget);
    expect(find.text('Filter zurücksetzen'), findsWidgets);
  });

  group('prices', () {
    testWidgets('one card shows exactly one price, the student one', (
      WidgetTester tester,
    ) async {
      await pumpCanteen(
        tester,
        meals: <Map<String, dynamic>>[_meal('1', 'Gemüsepfanne')],
      );

      expect(find.text('Studierende'), findsOneWidget);
      expect(find.text('Beschäftigte'), findsNothing);
      expect(find.textContaining('1,95'), findsOneWidget);
      expect(find.textContaining('4,95'), findsNothing);
    });

    testWidgets('choosing another group replaces the price, not adds to it', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{PreferenceKeys.canteenPriceGroup: 'employee'},
      );

      await pumpCanteen(
        tester,
        store: store,
        meals: <Map<String, dynamic>>[_meal('1', 'Gemüsepfanne')],
      );

      expect(find.text('Beschäftigte'), findsOneWidget);
      expect(find.textContaining('4,95'), findsOneWidget);
      expect(find.text('Studierende'), findsNothing);
      expect(find.textContaining('1,95'), findsNothing);
    });

    testWidgets('a missing price is stated, never substituted', (
      WidgetTester tester,
    ) async {
      // Another group's price is a different number for a different person.
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{PreferenceKeys.canteenPriceGroup: 'guest'},
      );

      await pumpCanteen(
        tester,
        store: store,
        meals: <Map<String, dynamic>>[_meal('1', 'Gemüsepfanne')],
      );

      expect(
        find.text('Für diese Preisgruppe ist kein Preis hinterlegt.'),
        findsOneWidget,
      );
      expect(find.textContaining('1,95'), findsNothing);
    });

    testWidgets('the sheet offers only the groups this canteen has', (
      WidgetTester tester,
    ) async {
      await pumpCanteen(tester);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(RadioListTile<String>, 'Studierende'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RadioListTile<String>, 'Beschäftigte'),
        findsOneWidget,
      );
      expect(find.widgetWithText(RadioListTile<String>, 'Gäste'), findsNothing);
    });
  });

  group('favourites', () {
    testWidgets('starring a dish persists and marks it in words', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = await pumpCanteen(
        tester,
        store: store,
      );

      await tester.tap(find.byTooltip('Zu Favoriten').first);
      await tester.pumpAndSettle();

      expect(
        container.read(canteenFilterProvider).favourites,
        contains('Gemüsepfanne'),
      );
      expect(
        store.getStringList(PreferenceKeys.canteenFavourites),
        contains('Gemüsepfanne'),
      );
      // A filled star and a semantic label, never colour alone.
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Favorit')), findsWidgets);
    });

    testWidgets('do not change the order and do not hide anything', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{
          PreferenceKeys.canteenFavourites: <String>['Schnitzel'],
        },
      );

      await pumpCanteen(tester, store: store);

      final List<MealCard> cards = tester
          .widgetList<MealCard>(find.byType(MealCard))
          .toList();
      expect(cards.map((MealCard card) => card.meal.name), <String>[
        'Gemüsepfanne',
        'Schnitzel',
      ]);
    });
  });

  testWidgets('a dish can no longer be hidden', (WidgetTester tester) async {
    await pumpCanteen(tester);
    expect(find.byTooltip('Gericht ausblenden'), findsNothing);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpCanteen(tester, locale: AppLocales.english);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Must contain'), findsOneWidget);
    expect(find.text('Must not contain'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Vegan'), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      const CanteenScreen(),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          _api(<Map<String, dynamic>>[
            _meal('1', 'Ein sehr langer Gerichtname für den Umbruchtest'),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
