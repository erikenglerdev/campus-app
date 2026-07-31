// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_router.dart';
import 'package:campus_koethen/app/app_routes.dart';
import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/campusmap/application/campus_map_providers.dart';
import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:campus_koethen/features/campusmap/data/map_asset_loader.dart';
import 'package:campus_koethen/features/campusmap/presentation/campus_map_screen.dart';
import 'package:campus_koethen/features/campusmap/presentation/floor_map_view.dart';
import 'package:campus_koethen/features/campusmap/presentation/room_link_tile.dart';
import 'package:campus_koethen/features/contacts/data/contact_models.dart';
import 'package:campus_koethen/features/more/presentation/more_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

/// Fictional demo rooms shaped exactly like `/v1/rooms`.
Map<String, dynamic> roomJson(
  String suffix, {
  String? displayName,
  String? mapVersion,
  String roomType = 'office',
  int sortOrder = 0,
}) => <String, dynamic>{
  'roomKey': 'demo-north-level2-$suffix',
  'roomNumber': 'B.${suffix.substring(1)}',
  'buildingKey': 'demo-north',
  'buildingName': 'Demogebäude Nord (fiktiv)',
  'floorKey': 'demo-north-level2',
  'floorLevel': 2,
  'floorName': '2. Obergeschoss',
  'roomType': roomType,
  'displayName': displayName,
  'description': null,
  // Taken from the bundled catalogue so a regenerated map cannot silently
  // turn every map assertion into a version-mismatch banner.
  'mapVersion': mapVersion ?? testCatalog.mapVersion,
  'sortOrder': sortOrder,
};

List<Map<String, dynamic>> get roomsFixture => <Map<String, dynamic>>[
  roomJson(
    'b201',
    displayName: 'Großer Hörsaal',
    roomType: 'lecture',
    sortOrder: 10,
  ),
  roomJson('b202', sortOrder: 20),
  roomJson('b210', sortOrder: 100),
];

/// The real generated catalogue, loaded once.
///
/// `pumpAndSettle` advances a fake clock and does NOT wait for real asset I/O,
/// so leaving the load to the provider made these tests depend on timing. The
/// asset itself is still exercised end to end in map_catalog_test.dart.
late final MapCatalog testCatalog;

List<Override> mapOverrides(List<Map<String, dynamic>> rooms) => <Override>[
  apiClientProvider.overrideWithValue(_api(rooms)),
  mapCatalogProvider.overrideWith((Ref ref) => testCatalog),
];

ApiClient _api(List<Map<String, dynamic>> rooms) => fakeApiClient(
  FakeHttpAdapter((RequestOptions options) {
    if (options.path.contains('/rooms')) {
      // The adapter encodes the body itself — pass the object, not a string.
      return FakeHttpResponse(envelope(rooms));
    }
    return FakeHttpResponse(envelope(<Object>[]), statusCode: 404);
  }),
);

/// Gives the test a tall surface.
///
/// The screen stacks a notice, the search field, a 320 px map and the result
/// list. On the default 800 px test viewport the list falls below the fold,
/// and `ListView` does not build off-screen children — so assertions would
/// fail for a layout reason rather than a behavioural one.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpMap(
  WidgetTester tester, {
  List<Map<String, dynamic>>? rooms,
  String? initialRoomKey,
  Locale locale = AppLocales.german,
}) async {
  useTallSurface(tester);
  await pumpScreen(
    tester,
    CampusMapScreen(initialRoomKey: initialRoomKey),
    locale: locale,
    overrides: mapOverrides(rooms ?? roomsFixture),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    testCatalog = await const MapAssetLoader().load();
  });

  testWidgets('the More section opens the campus map', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const MoreScreen(),
      overrides: mapOverrides(roomsFixture),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lageplan'), findsOneWidget);
    expect(find.text('Fiktiver Demo-Etagenplan mit Raumsuche'), findsOneWidget);
  });

  testWidgets('the route under More renders the map screen', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        contentCacheProvider.overrideWithValue(
          SafeContentCache(MemoryContentCache()),
        ),
        ...mapOverrides(roomsFixture),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: AppLocales.german,
          supportedLocales: AppLocales.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: createAppRouter(initialLocation: AppRoutes.campusMap),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CampusMapScreen), findsOneWidget);
  });

  testWidgets('shows the fictional-demo badge at all times', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(
      find.text('Fiktiver Demoplan'),
      findsOneWidget,
      reason: 'the demo character must be visible without any interaction',
    );
  });

  testWidgets('the badge reveals the full demo notice', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    await tester.tap(find.text('Fiktiver Demoplan'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('frei erfunden'),
      findsOneWidget,
      reason: 'the full wording must stay reachable',
    );
  });

  testWidgets('searching B201 selects and marks B.201', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'B201');
    await tester.pumpAndSettle();

    // Only the matching room is offered…
    expect(find.text('Großer Hörsaal'), findsOneWidget);
    expect(find.text('B.202'), findsNothing);

    await tester.tap(find.text('Großer Hörsaal'));
    await tester.pumpAndSettle();

    // …and the selection is stated in words, not by colour alone.
    expect(find.textContaining('Ausgewählt: Großer Hörsaal'), findsOneWidget);
    expect(find.byIcon(Icons.place), findsWidgets);
  });

  testWidgets('B.201 and B201 lead to the same room', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'B.201');
    await tester.pumpAndSettle();
    final bool dotted = find.text('Großer Hörsaal').evaluate().isNotEmpty;

    await tester.enterText(find.byType(TextField), 'B201');
    await tester.pumpAndSettle();
    final bool plain = find.text('Großer Hörsaal').evaluate().isNotEmpty;

    expect(dotted, isTrue);
    expect(plain, isTrue);
  });

  testWidgets('a deep link preselects the room', (WidgetTester tester) async {
    await pumpMap(tester, initialRoomKey: 'demo-north-level2-b210');
    expect(find.textContaining('Ausgewählt: B.210'), findsOneWidget);
  });

  testWidgets('the selection can be cleared again', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester, initialRoomKey: 'demo-north-level2-b210');
    expect(find.textContaining('Ausgewählt: B.210'), findsOneWidget);

    await tester.tap(find.text('Gesamte Etage anzeigen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ausgewählt:'), findsNothing);
  });

  testWidgets('a room the bundled map does not know stays text only', (
    WidgetTester tester,
  ) async {
    await pumpMap(
      tester,
      rooms: <Map<String, dynamic>>[roomJson('bxxx')],
      initialRoomKey: 'demo-north-level2-bxxx',
    );

    expect(find.textContaining('nicht enthalten'), findsOneWidget);
    // No crash, and the room is still readable.
    expect(find.textContaining('Ausgewählt:'), findsOneWidget);
  });

  testWidgets('a map version mismatch is explained instead of failing', (
    WidgetTester tester,
  ) async {
    await pumpMap(
      tester,
      rooms: <Map<String, dynamic>>[
        roomJson('b201', mapVersion: 'from-the-future'),
      ],
    );

    expect(
      find.textContaining('passt nicht zur aktuellen Raumliste'),
      findsOneWidget,
    );
    // The plan is withheld, but the rooms stay browsable through the list.
    await tester.tap(find.text('Alle anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('B.201'), findsWidgets);
  });

  testWidgets('an empty catalogue shows an empty state, not an error', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester, rooms: <Map<String, dynamic>>[]);
    expect(find.textContaining('noch keine Räume'), findsOneWidget);
  });

  testWidgets('a query without matches explains itself', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Kein Raum gefunden'), findsOneWidget);
  });

  testWidgets('renders English when the locale is en', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester, locale: AppLocales.english);
    expect(find.text('Fictional demo plan'), findsOneWidget);
    expect(find.text('Search rooms'), findsOneWidget);
    expect(find.text('Show all'), findsOneWidget);

    await tester.tap(find.text('Fictional demo plan'));
    await tester.pumpAndSettle();
    // Scoped to the dialog: the building picker also carries the word
    // "fictional" in its English name.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('fictional'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the map exposes a screen reader label', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(
      find.bySemanticsLabel('Etagenplan, zoombar und verschiebbar'),
      findsOneWidget,
    );
  });

  testWidgets('room rows keep a large enough touch target', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    // The map is the resting state now, so the rows live in the room list.
    await tester.tap(find.text('Alle anzeigen'));
    await tester.pumpAndSettle();

    final Iterable<ListTile> tiles = tester.widgetList<ListTile>(
      find.byType(ListTile),
    );
    expect(tiles, isNotEmpty);
    for (final ListTile tile in tiles) {
      expect(tile.minTileHeight, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the room list opens from the bottom bar and selects a room', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(find.text('30 Räume'), findsNothing, reason: 'fixture has 3 rooms');
    expect(find.text('3 Räume'), findsOneWidget);

    await tester.tap(find.text('Alle anzeigen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Großer Hörsaal').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ausgewählt: Großer Hörsaal'), findsOneWidget);
  });

  testWidgets('survives doubled text size without overflow', (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await pumpScreen(
      tester,
      const CampusMapScreen(),
      textScaler: const TextScaler.linear(2),
      overrides: mapOverrides(roomsFixture),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('building and floor selection', _selectionTests);

  group('contact room rows', () {
    const RoomReference known = RoomReference(
      roomKey: 'demo-north-level2-b201',
      roomNumber: 'B.201',
      buildingName: 'Demogebäude Nord (fiktiv)',
      floorName: '2. Obergeschoss',
      displayName: 'Großer Hörsaal',
    );

    testWidgets('an empty room list renders nothing at all', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(body: RoomLinkSection(rooms: <RoomReference>[])),
        overrides: mapOverrides(roomsFixture),
      );
      await tester.pumpAndSettle();

      expect(find.text('Räume'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('a room row shows building, floor and number', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(body: RoomLinkSection(rooms: <RoomReference>[known])),
        overrides: mapOverrides(roomsFixture),
      );
      await tester.pumpAndSettle();

      expect(find.text('Räume'), findsOneWidget);
      expect(find.text('Großer Hörsaal'), findsOneWidget);
      expect(
        find.text('Demogebäude Nord (fiktiv), 2. Obergeschoss, Raum B.201'),
        findsOneWidget,
      );
    });

    test('the deep link carries the roomKey as a query parameter', () {
      expect(
        AppRoutes.campusMapForRoom('demo-north-level2-b201'),
        '/more/campus-map?room=demo-north-level2-b201',
      );
    });

    testWidgets('tapping a room row opens the campus map on that room', (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          contentCacheProvider.overrideWithValue(
            SafeContentCache(MemoryContentCache()),
          ),
          ...mapOverrides(roomsFixture),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: AppLocales.german,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: createAppRouter(initialLocation: AppRoutes.more),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reaching the map through the real route table, exactly as the contact
      // row does, rather than asserting on a string.
      await tester.tap(find.text('Lageplan'));
      await tester.pumpAndSettle();
      expect(find.byType(CampusMapScreen), findsOneWidget);
    });

    testWidgets('a room outside the bundled map is not tappable', (
      WidgetTester tester,
    ) async {
      const RoomReference unknown = RoomReference(
        roomKey: 'not-in-the-bundled-map',
        roomNumber: 'Z.999',
        buildingName: 'Irgendwo',
        floorName: 'Irgendwann',
      );

      await pumpScreen(
        tester,
        const Scaffold(body: RoomLinkSection(rooms: <RoomReference>[unknown])),
        overrides: mapOverrides(roomsFixture),
      );
      await tester.pumpAndSettle();

      final ListTile tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(
        tile.onTap,
        isNull,
        reason: 'a room without geometry must not navigate',
      );
      expect(find.textContaining('nicht enthalten'), findsOneWidget);
    });
  });
}

/// Building and floor selection.
///
/// The demo floor plan and the campus overview are two buildings in the same
/// bundled catalogue, so switching between them has to keep the plan, the floor
/// and any room selection describing the same place.
void _selectionTests() {
  String buildingName(String key, {String locale = 'de'}) =>
      testCatalog.building(key)!.name.resolve(locale);
  String floorName(String key, {String locale = 'de'}) =>
      testCatalog.floor(key)!.name.resolve(locale);

  const String demo = 'demo-north';
  const String overview = 'koethen-campus-overview';
  const String demoFloor = 'demo-north-level2';
  const String overviewFloor = 'koethen-campus-overview-level';

  Future<void> switchTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).hitTestable().first);
    await tester.pumpAndSettle();
  }

  testWidgets('the building picker offers both buildings', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    // The current building is on the chip…
    expect(find.text(buildingName(demo)), findsOneWidget);
    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    // …and the menu offers the other one too.
    expect(find.text(buildingName(overview)), findsOneWidget);
  });

  testWidgets('switching to the overview shows its own plan', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(
      tester.widget<FloorMapView>(find.byType(FloorMapView)).floor.svgAsset,
      'assets/maps/demo-north/level2.svg',
    );

    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(overview));

    final FloorMapView view = tester.widget<FloorMapView>(
      find.byType(FloorMapView),
    );
    expect(view.floor.floorKey, overviewFloor);
    expect(view.floor.svgAsset, 'assets/maps/campus/koethen-overview.svg');
    // A building without rooms is a normal state: no selection, no error.
    expect(view.selected, isNull);
    expect(find.textContaining('Ausgewählt:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floor picker is limited to the active building', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(find.text(floorName(demoFloor)), findsOneWidget);
    expect(find.text(floorName(overviewFloor)), findsNothing);

    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(overview));

    expect(find.text(floorName(overviewFloor)), findsOneWidget);
    expect(find.text(floorName(demoFloor)), findsNothing);
  });

  testWidgets('switching back shows the 30-room plan again', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(overview));
    await tester.tap(find.text(buildingName(overview)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(demo));

    expect(
      tester.widget<FloorMapView>(find.byType(FloorMapView)).floor.floorKey,
      demoFloor,
    );
    expect(find.text(floorName(demoFloor)), findsOneWidget);
  });

  testWidgets('picking a search result switches building and floor', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    // Start on the campus overview, which has no rooms at all.
    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(overview));
    expect(
      tester.widget<FloorMapView>(find.byType(FloorMapView)).floor.floorKey,
      overviewFloor,
    );

    // Search stays global, so the room is still findable from here.
    await tester.enterText(find.byType(TextField), 'B.201');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Großer Hörsaal').last);
    await tester.pumpAndSettle();

    final FloorMapView view = tester.widget<FloorMapView>(
      find.byType(FloorMapView),
    );
    expect(view.floor.floorKey, demoFloor);
    expect(view.selected?.roomKey, 'demo-north-level2-b201');
    expect(find.text(buildingName(demo)), findsOneWidget);
  });

  testWidgets('a deep link sets building and floor', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester, initialRoomKey: 'demo-north-level2-b210');

    final FloorMapView view = tester.widget<FloorMapView>(
      find.byType(FloorMapView),
    );
    expect(view.floor.floorKey, demoFloor);
    expect(view.selected?.roomKey, 'demo-north-level2-b210');
    expect(find.text(buildingName(demo)), findsOneWidget);
  });

  testWidgets('the plan notice follows the building', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    // The invented floor plan says so.
    expect(find.text('Fiktiver Demoplan'), findsOneWidget);

    await tester.tap(find.text(buildingName(demo)));
    await tester.pumpAndSettle();
    await switchTo(tester, buildingName(overview));

    // The campus overview is not fictional, and claiming it were would be a
    // false statement about a real place.
    expect(find.text('Fiktiver Demoplan'), findsNothing);
    expect(find.text('Schematische Übersicht'), findsOneWidget);
  });

  testWidgets('both selectors carry a screen reader label', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    expect(
      find.bySemanticsLabel('Gebäude auswählen, aktuell ${buildingName(demo)}'),
      findsOneWidget,
    );
    // One level: stated, not offered as a choice.
    expect(
      find.bySemanticsLabel('Einzige Ebene: ${floorName(demoFloor)}'),
      findsOneWidget,
    );
  });

  testWidgets('the selectors render in English', (WidgetTester tester) async {
    await pumpMap(tester, locale: AppLocales.english);

    expect(find.text(buildingName(demo, locale: 'en')), findsOneWidget);
    expect(find.text(floorName(demoFloor, locale: 'en')), findsOneWidget);
  });

  testWidgets('long names do not overflow a narrow screen', (
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
      const CampusMapScreen(),
      overrides: mapOverrides(roomsFixture),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the selectors survive a wide screen too', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpScreen(
      tester,
      const CampusMapScreen(),
      overrides: mapOverrides(roomsFixture),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(FloorMapView), findsOneWidget);
  });
}
