// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/search/application/search_providers.dart';
import 'package:campus_koethen/features/search/domain/search_index.dart';
import 'package:campus_koethen/features/search/domain/search_result.dart';
import 'package:campus_koethen/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

const List<SearchEntry> _index = <SearchEntry>[
  SearchEntry(
    category: SearchCategory.section,
    title: 'Mensa',
    route: '/canteen',
  ),
  SearchEntry(
    category: SearchCategory.room,
    title: 'B.201',
    subtitle: 'Demogebäude Nord · 2. Obergeschoss',
    route: '/more/campus-map?room=demo-north-level2-b201',
    keywords: <String>['B201'],
  ),
  SearchEntry(
    category: SearchCategory.contact,
    title: 'Studierendenrat',
    route: '/contacts/studierendenrat',
  ),
  SearchEntry(
    category: SearchCategory.meal,
    title: 'Gemüsepfanne',
    route: '/canteen',
  ),
];

Future<void> pumpSearch(
  WidgetTester tester, {
  Locale locale = AppLocales.german,
  List<SearchEntry> index = _index,
  TextScaler textScaler = TextScaler.noScaling,
  Size surface = const Size(390, 1400),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    const SearchScreen(),
    locale: locale,
    textScaler: textScaler,
    overrides: <Override>[searchIndexProvider.overrideWithValue(index)],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts empty and invites typing', (WidgetTester tester) async {
    await pumpSearch(tester);
    expect(find.text('Tippe, um zu suchen.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('states what it does and does not reach', (
    WidgetTester tester,
  ) async {
    // A user has to be able to tell that mail and grades are not in here.
    await pumpSearch(tester);
    expect(
      find.textContaining('Mail, Noten und Moodle bleiben außen vor'),
      findsOneWidget,
    );
  });

  testWidgets('finds across sources and groups by category', (
    WidgetTester tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'e');
    await tester.pumpAndSettle();

    // Category headings, not one flat list.
    expect(find.text('Bereiche'), findsOneWidget);
    expect(find.text('Kontakte'), findsOneWidget);
    expect(find.text('Mensa'), findsWidgets);
  });

  testWidgets('a room is found with and without its dot', (
    WidgetTester tester,
  ) async {
    await pumpSearch(tester);

    // Scoped to the result list — the query itself also reads "B.201".
    Finder hit() => find.descendant(
      of: find.byType(ListTile),
      matching: find.text('B.201'),
    );

    await tester.enterText(find.byType(TextField), 'b201');
    await tester.pumpAndSettle();
    expect(hit(), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'B.201');
    await tester.pumpAndSettle();
    expect(hit(), findsOneWidget);
  });

  testWidgets('an unmatched query explains itself', (
    WidgetTester tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'zzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nichts gefunden'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('clearing the query returns to the invitation', (
    WidgetTester tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'mensa');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);

    await tester.tap(find.byTooltip('Eingabe löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Tippe, um zu suchen.'), findsOneWidget);
  });

  testWidgets('an empty index is not an error', (WidgetTester tester) async {
    // Offline before anything was ever loaded: nothing to search, but the
    // screen still works and says so.
    await pumpSearch(tester, index: const <SearchEntry>[]);

    await tester.enterText(find.byType(TextField), 'mensa');
    await tester.pumpAndSettle();

    expect(find.text('Nichts gefunden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpSearch(tester, locale: AppLocales.english);
    expect(find.text('Start typing to search.'), findsOneWidget);
    expect(
      find.textContaining('Mail, grades and Moodle are excluded'),
      findsOneWidget,
    );
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    await pumpSearch(
      tester,
      textScaler: const TextScaler.linear(2),
      surface: const Size(320, 2400),
    );

    await tester.enterText(find.byType(TextField), 'b');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
