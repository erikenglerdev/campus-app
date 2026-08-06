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
import 'package:campus_koethen/features/campusmap/presentation/room_link.dart';
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
  int level = 2,
}) => <String, dynamic>{
  'roomKey': 'demo-north-level$level-$suffix',
  'roomNumber': 'B.${suffix.substring(1)}',
  'buildingKey': 'demo-north',
  'buildingName': 'Demogebäude Nord (fiktiv)',
  'floorKey': 'demo-north-level$level',
  'floorLevel': level,
  'floorName': '$level. Obergeschoss',
  'roomType': roomType,
  'displayName': displayName,
  'description': null,
  // Taken from the bundled catalogue so a regenerated map cannot silently
  // turn every map assertion into a version-mismatch banner.
  'mapVersion': mapVersion ?? testCatalog.mapVersion,
  'sortOrder': sortOrder,
};

List<Map<String, dynamic>> get roomsFixture => <Map<String, dynamic>>[
  // The lower storey, which the map opens on…
  roomJson(
    'b101',
    displayName: 'Kleiner Hörsaal',
    roomType: 'lecture',
    sortOrder: 10,
    level: 1,
  ),
  roomJson('b102', sortOrder: 20, level: 1),
  // …and the upper one, reachable through the floor picker or a deep link.
  roomJson(
    'b201',
    displayName: 'Großer Hörsaal',
    roomType: 'lecture',
    sortOrder: 110,
  ),
  roomJson('b202', sortOrder: 120),
  roomJson('b210', sortOrder: 200),
];

/// The real generated catalogue, loaded once.
///
/// `pumpAndSettle` advances a fake clock and does NOT wait for real asset I/O,
/// so leaving the load to the provider made these tests depend on timing. The
/// asset itself is still exercised end to end in map_catalog_test.dart.
late final MapCatalog testCatalog;

/// A fictional contact point whose staff sit in the rooms above.
///
/// Shaped like `/v1/contact-areas/search-index`, because the room search now
/// reads that index to answer "which room does this person sit in".
List<Map<String, dynamic>> get contactIndexFixture => <Map<String, dynamic>>[
  <String, dynamic>{
    'slug': 'demo-pruefungsamt',
    'name': 'Demo-Prüfungsamt (fiktiv)',
    'shortDescription': 'Beispielbereich',
    'descriptionText': 'Nur zu Demonstrationszwecken.',
    'rooms': <Map<String, dynamic>>[],
    'persons': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Björn Demoperson',
        'role': 'Beispielrolle',
        'rooms': <Map<String, dynamic>>[
          <String, dynamic>{
            'roomKey': 'demo-north-level2-b210',
            'roomNumber': 'B.210',
            'buildingName': 'Demogebäude Nord (fiktiv)',
            'floorName': '2. Obergeschoss',
          },
        ],
      },
    ],
  },
];

List<Override> mapOverrides(
  List<Map<String, dynamic>> rooms, {
  List<Map<String, dynamic>>? contacts,
}) => <Override>[
  apiClientProvider.overrideWithValue(_api(rooms, contacts)),
  mapCatalogProvider.overrideWith((Ref ref) => testCatalog),
];

ApiClient _api(
  List<Map<String, dynamic>> rooms,
  List<Map<String, dynamic>>? contacts,
) => fakeApiClient(
  FakeHttpAdapter((RequestOptions options) {
    if (options.path.contains('/contact-areas/search-index')) {
      // Answered even when a test passes none: an index that errors would
      // leave Riverpod retrying in the background of every map test.
      return FakeHttpResponse(
        envelope(contacts ?? const <Map<String, dynamic>>[]),
      );
    }
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
  List<Map<String, dynamic>>? contacts,
  String? initialRoomKey,
  Locale locale = AppLocales.german,
}) async {
  useTallSurface(tester);
  await pumpScreen(
    tester,
    CampusMapScreen(initialRoomKey: initialRoomKey),
    locale: locale,
    overrides: mapOverrides(rooms ?? roomsFixture, contacts: contacts),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('map controls', _controlPositionTests);

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

    // The hub uses the module's full title; "Lageplan" alone is the short one.
    expect(find.text('Lageplan & Räume'), findsOneWidget);
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

  testWidgets('the bare number finds the room without its building letter', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), '202');
    await tester.pumpAndSettle();

    expect(find.text('B.202'), findsWidgets);
    expect(find.text('Großer Hörsaal'), findsNothing);
  });

  testWidgets('a person leads to their room, and says so', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester, contacts: contactIndexFixture);

    await tester.enterText(find.byType(TextField), 'Demoperson');
    await tester.pumpAndSettle();

    // The room is offered even though the typed name is nowhere in it — so the
    // row has to explain itself.
    expect(find.text('B.210'), findsWidgets);
    expect(
      find.textContaining('Gefunden über Björn Demoperson'),
      findsOneWidget,
    );

    await tester.tap(find.text('B.210').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ausgewählt: B.210'), findsOneWidget);
  });

  testWidgets('the room search still works without a contact index', (
    WidgetTester tester,
  ) async {
    // What an offline start looks like: no index, so no person search — but
    // the plain room search is untouched.
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Demoperson');
    await tester.pumpAndSettle();
    expect(find.text('Kein Raum gefunden'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'B.202');
    await tester.pumpAndSettle();
    expect(find.text('B.202'), findsWidgets);
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
    // The plan is withheld, but the rooms stay reachable through the search.
    await tester.enterText(find.byType(TextField), 'B201');
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

    // The map is the resting state, so the rows live in the search results.
    await tester.enterText(find.byType(TextField), 'B2');
    await tester.pumpAndSettle();

    final Iterable<ListTile> tiles = tester.widgetList<ListTile>(
      find.byType(ListTile),
    );
    expect(tiles, isNotEmpty);
    for (final ListTile tile in tiles) {
      expect(tile.minTileHeight, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('no room count and no "show all" bar at the bottom', (
    WidgetTester tester,
  ) async {
    // The bar took a strip of the map to say something the map already shows.
    await pumpMap(tester);

    expect(find.text('3 Räume'), findsNothing);
    expect(find.text('Alle anzeigen'), findsNothing);
  });

  testWidgets('a room is selected through the search', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);

    await tester.enterText(find.byType(TextField), 'Großer');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Großer Hörsaal').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ausgewählt: Großer Hörsaal'), findsOneWidget);
  });

  group('tapping a room on the plan', () {
    /// Where a point of the PLAN currently sits on screen.
    Offset planPointOnScreen(WidgetTester tester, Offset planPoint) {
      final FloorMapViewState state = tester.state<FloorMapViewState>(
        find.byType(FloorMapView),
      );
      final FloorMapView view = tester.widget<FloorMapView>(
        find.byType(FloorMapView),
      );
      final Rect box = tester.getRect(find.byType(FloorMapView));
      final double scale = state.planScale;
      final Size planSize = Size(
        view.floor.viewBox.width * scale,
        view.floor.viewBox.height * scale,
      );
      // The plan is centred inside the view before the transform applies.
      final Offset inChild =
          Offset(
            (box.width - planSize.width) / 2,
            (box.height - planSize.height) / 2,
          ) +
          planPoint * scale;
      return box.topLeft +
          MatrixUtils.transformPoint(state.currentTransform, inChild);
    }

    testWidgets('selects it exactly as the search would', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester);

      // The centre of the first room in plan coordinates, from the bundled
      // catalogue. Both storeys share this drawing, so the tap must resolve to
      // the room of the floor on screen — the lower one — and not to the
      // identically shaped room above it.
      await tester.tapAt(planPointOnScreen(tester, const Offset(195, 310)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ausgewählt: Kleiner Hörsaal'),
        findsOneWidget,
      );
      expect(find.textContaining('Großer Hörsaal'), findsNothing);
      expect(find.byIcon(Icons.place), findsWidgets);
    });

    testWidgets('a tap on empty floor changes nothing', (
      WidgetTester tester,
    ) async {
      await pumpMap(tester);

      // The far corner of the plan: no room is anywhere near it.
      await tester.tapAt(planPointOnScreen(tester, Offset.zero));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ausgewählt:'), findsNothing);
    });

    testWidgets('a room the API does not serve is not selectable', (
      WidgetTester tester,
    ) async {
      // The bundled map knows B.203; the fixture does not. Without a room
      // record there is no name and no detail to show, so the tap does
      // nothing rather than opening an empty sheet.
      await pumpMap(tester);

      await tester.tapAt(planPointOnScreen(tester, const Offset(500, 310)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ausgewählt:'), findsNothing);
    });

    testWidgets('still hits the right room after the plan has moved', (
      WidgetTester tester,
    ) async {
      // Selecting zooms and pans; a second tap has to keep working.
      await pumpMap(tester);
      await tester.tapAt(planPointOnScreen(tester, const Offset(195, 310)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ausgewählt: Kleiner Hörsaal'),
        findsOneWidget,
      );

      // B.102 sits next door. Zoomed in, its centre is off screen, so the
      // target is the part of it that is actually visible — which is exactly
      // the situation this has to survive.
      await tester.tapAt(planPointOnScreen(tester, const Offset(310, 310)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ausgewählt: B.102'), findsOneWidget);
    });
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
      await tester.tap(find.text('Lageplan & Räume'));
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
  // The demo building has two storeys drawn from one another. The map opens on
  // the lower one, the way a house is read from the ground up.
  const String demoFloor = 'demo-north-level1';
  const String demoUpperFloor = 'demo-north-level2';
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
      'assets/maps/demo-north/level1.svg',
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

  testWidgets('switching back shows the demo plan again', (
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
    expect(view.floor.floorKey, demoUpperFloor);
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
    expect(view.floor.floorKey, demoUpperFloor);
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
    // Two storeys: a real choice, announced as one.
    expect(
      find.bySemanticsLabel('Etage auswählen, aktuell ${floorName(demoFloor)}'),
      findsOneWidget,
    );
  });

  testWidgets('the floor picker switches storeys inside the building', (
    WidgetTester tester,
  ) async {
    await pumpMap(tester);
    expect(
      tester.widget<FloorMapView>(find.byType(FloorMapView)).floor.floorKey,
      demoFloor,
    );

    await tester.tap(find.text(floorName(demoFloor)));
    await tester.pumpAndSettle();
    await switchTo(tester, floorName(demoUpperFloor));

    final FloorMapView view = tester.widget<FloorMapView>(
      find.byType(FloorMapView),
    );
    expect(view.floor.floorKey, demoUpperFloor);
    expect(view.floor.svgAsset, 'assets/maps/demo-north/level2.svg');
    // The building did not change with it.
    expect(find.text(buildingName(demo)), findsOneWidget);
  });

  testWidgets('a room selection carries the map to its own storey', (
    WidgetTester tester,
  ) async {
    // The two plans are the same drawing, so landing on the right SHAPE proves
    // nothing — only the floor key does.
    await pumpMap(tester, initialRoomKey: 'demo-north-level2-b210');

    expect(
      tester.widget<FloorMapView>(find.byType(FloorMapView)).floor.floorKey,
      demoUpperFloor,
    );
    expect(find.text(floorName(demoUpperFloor)), findsOneWidget);
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

/// The building and floor controls sit on the left and stay inside the screen.
void _controlPositionTests() {
  testWidgets('the controls are left-aligned', (WidgetTester tester) async {
    await pumpMap(tester);

    final Finder controls = find.byType(PositionedDirectional).first;
    final PositionedDirectional positioned = tester
        .widget<PositionedDirectional>(controls);
    expect(positioned.start, isNotNull);
    expect(positioned.end, isNull);
  });

  testWidgets('the label ellipsises instead of growing', (
    WidgetTester tester,
  ) async {
    // The preferred label width is wider than a narrow phone can spare, so a
    // long building name must be cut rather than push the control across the
    // map. The width itself is clamped to what the screen actually offers.
    await pumpMap(tester);

    final Text label = tester.widget<Text>(
      find.textContaining('Obergeschoss').first,
    );
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.maxLines, 1);
  });
}
