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
  List<Map<String, dynamic>> markers = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'subtitle': null,
  'sourceLanguage': 'de',
  'isSprint': false,
  'extras': <String>[],
  'markers': markers,
  'prices': <Map<String, dynamic>>[
    <String, dynamic>{
      'group': 'student',
      'label': 'Studierende',
      'amount': '1.95',
      'currency': 'EUR',
      'isStudentGroup': true,
    },
    <String, dynamic>{
      'group': 'employee',
      'label': 'Beschäftigte',
      'amount': '4.95',
      'currency': 'EUR',
      'isStudentGroup': false,
    },
  ],
};

Map<String, dynamic> _marker(String code, String label) => <String, dynamic>{
  'code': code,
  'label': label,
  'kind': 'ingredient',
};

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
                _meal(
                  '1',
                  'Gemüsepfanne',
                  markers: <Map<String, dynamic>>[_marker('52', 'vegan')],
                ),
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
  testWidgets('without a filter every dish is listed', (
    WidgetTester tester,
  ) async {
    await pumpCanteen(tester);
    expect(find.text('Gemüsepfanne'), findsOneWidget);
    expect(find.text('Schnitzel'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('the filter offers only markings the source published', (
    WidgetTester tester,
  ) async {
    // This is the whole point: no hardcoded vocabulary, so the app can never
    // offer a filter the data cannot honour.
    await pumpCanteen(tester);

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'vegan'), findsNWidgets(2));
    expect(find.widgetWithText(FilterChip, 'vegetarisch'), findsNothing);
  });

  testWidgets('a day without markings says so instead of offering nothing', (
    WidgetTester tester,
  ) async {
    await pumpCanteen(
      tester,
      meals: <Map<String, dynamic>>[_meal('1', 'Schnitzel')],
    );

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Für diesen Tag liefert die Quelle keine Kennzeichnungen.'),
      findsOneWidget,
    );
  });

  testWidgets('requiring a marking narrows the list', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.canteenRequiredMarkers, <String>[
      '52',
    ]);

    await pumpCanteen(tester, store: store);

    expect(find.text('Gemüsepfanne'), findsOneWidget);
    expect(find.text('Schnitzel'), findsNothing);
    expect(find.text('Filter aktiv'), findsOneWidget);
  });

  testWidgets('a filter that matches nothing offers a way out', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.canteenRequiredMarkers, <String>[
      'does-not-exist',
    ]);

    await pumpCanteen(tester, store: store);

    // Different from "nothing on offer", and this one has a remedy.
    expect(find.text('Kein Gericht passt zu deinem Filter.'), findsOneWidget);
    expect(find.text('Filter zurücksetzen'), findsWidgets);
  });

  testWidgets('starring a dish persists and marks it in words', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer container = await pumpCanteen(tester, store: store);

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

  testWidgets('hiding a dish removes it and reports the count', (
    WidgetTester tester,
  ) async {
    await pumpCanteen(tester);

    await tester.tap(find.byTooltip('Gericht ausblenden').first);
    await tester.pumpAndSettle();

    expect(find.text('Gemüsepfanne'), findsNothing);
    expect(find.text('1 Gericht ausgeblendet'), findsOneWidget);
  });

  testWidgets('favourites are listed first', (WidgetTester tester) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.canteenFavourites, <String>[
      'Schnitzel',
    ]);

    await pumpCanteen(tester, store: store);

    final List<MealCard> cards = tester
        .widgetList<MealCard>(find.byType(MealCard))
        .toList();
    expect(cards.first.meal.name, 'Schnitzel');
  });

  testWidgets('every price group stays visible when one is emphasised', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setString(PreferenceKeys.canteenPriceGroup, 'employee');

    await pumpCanteen(tester, store: store);

    // The emphasis moved, but nothing was removed.
    expect(find.text('Studierende'), findsWidgets);
    expect(find.text('Beschäftigte'), findsWidgets);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpCanteen(tester, locale: AppLocales.english);
    expect(find.text('Filters'), findsOneWidget);
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
