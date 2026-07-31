// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/campusmap/data/map_asset_loader.dart';
import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled catalogue', () {
    test('loads both generated buildings', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();

      expect(catalog.mapVersion, isNotEmpty);
      expect(catalog.rooms, hasLength(30));
      expect(catalog.floors, hasLength(2));
      expect(catalog.buildings, hasLength(2));
      expect(catalog.buildings.map((MapBuilding b) => b.buildingKey), <String>[
        'demo-north',
        'koethen-campus-overview',
      ]);
      expect(catalog.hasSeveralBuildings, isTrue);
    });

    test('carries building and floor names in both languages', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();

      final MapBuilding overview = catalog.building('koethen-campus-overview')!;
      expect(overview.name.resolve('de'), 'Campus Köthen – Übersicht');
      expect(overview.name.resolve('en'), 'Campus Köthen – Overview');

      final MapFloor floor = catalog.floor('koethen-campus-overview-level')!;
      expect(floor.name.resolve('de'), 'Campusübersicht');
      expect(floor.name.resolve('en'), 'Campus overview');

      final MapBuilding demo = catalog.building('demo-north')!;
      expect(demo.name.resolve('de'), 'Demogebäude Nord (fiktiv)');
      expect(demo.name.resolve('en'), 'Demo building north (fictional)');
      expect(
        catalog.floor('demo-north-level2')!.name.resolve('en'),
        'Second floor',
      );

      // An unsupported locale falls back to German rather than to a key.
      expect(overview.name.resolve('fr'), 'Campus Köthen – Übersicht');
    });

    test('states what kind of drawing each building is', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();

      expect(catalog.building('demo-north')!.planKind, PlanKind.fictional);
      expect(
        catalog.building('koethen-campus-overview')!.planKind,
        PlanKind.schematic,
      );
      // An unknown value must not silently become a promise about a real place.
      expect(PlanKind.fromName('something-new'), PlanKind.fictional);
      expect(PlanKind.fromName(null), PlanKind.fictional);
    });

    test('a building without rooms is a normal state, not an error', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();

      final List<MapFloor> floors = catalog.floorsOf('koethen-campus-overview');
      expect(floors, hasLength(1));
      expect(floors.single.floorKey, 'koethen-campus-overview-level');
      expect(floors.single.svgAsset, 'assets/maps/campus/koethen-overview.svg');
      expect(
        catalog.rooms.where(
          (MapRoomGeometry r) => r.buildingKey == 'koethen-campus-overview',
        ),
        isEmpty,
      );
    });

    test('floors are scoped to their building', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();

      expect(
        catalog.floorsOf('demo-north').map((MapFloor f) => f.floorKey),
        <String>['demo-north-level2'],
      );
      expect(catalog.floorsOf('does-not-exist'), isEmpty);
      expect(catalog.buildingOfFloor('demo-north-level2'), 'demo-north');
      expect(
        catalog.buildingOfFloor('koethen-campus-overview-level'),
        'koethen-campus-overview',
      );
      expect(catalog.buildingOfFloor('nope'), isNull);
      expect(catalog.building('nope'), isNull);
    });

    test('resolves geometry for a known room', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      final MapRoomGeometry? geometry = catalog.geometryFor(
        'demo-north-level2-b201',
      );

      expect(geometry, isNotNull);
      expect(geometry!.floorKey, 'demo-north-level2');
      expect(geometry.svgElementId, 'room-demo-north-level2-b201');
      expect(geometry.bounds.width, greaterThan(0));
      expect(geometry.focus.dx, greaterThan(0));
    });

    test('returns null for an unknown room instead of throwing', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      expect(catalog.geometryFor('does-not-exist'), isNull);
    });

    test('exposes the floor with its SVG asset and viewBox', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      final MapFloor? floor = catalog.floor('demo-north-level2');

      expect(floor, isNotNull);
      expect(floor!.svgAsset, 'assets/maps/demo-north/level2.svg');
      expect(floor.viewBox.width, greaterThan(0));
      expect(floor.level, 2);
    });

    test('every room resolves to an existing floor', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      for (final MapRoomGeometry room in catalog.rooms) {
        expect(
          catalog.floor(room.floorKey),
          isNotNull,
          reason: '${room.roomKey} points at an unknown floor',
        );
      }
    });
  });

  group('map version compatibility', () {
    test('accepts a matching version', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      expect(catalog.supportsMapVersion(catalog.mapVersion), isTrue);
    });

    test('reports a mismatch so the UI can explain it', () async {
      final MapCatalog catalog = await const MapAssetLoader().load();
      expect(catalog.supportsMapVersion('some-other-version'), isFalse);
    });

    test('treats an empty or missing server version as compatible', () async {
      // A room without mapVersion must not disable the map; the geometry lookup
      // is what really decides whether a room can be shown.
      final MapCatalog catalog = await const MapAssetLoader().load();
      expect(catalog.supportsMapVersion(''), isTrue);
      expect(catalog.supportsMapVersion(null), isTrue);
    });
  });

  group('parsing', () {
    test('rejects a payload without rooms rather than half-loading it', () {
      expect(MapCatalog.fromJson(<String, dynamic>{'mapVersion': 'x'}), isNull);
    });

    test('skips a malformed room but keeps the rest', () {
      final MapCatalog? catalog = MapCatalog.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mapVersion': 'x',
        'buildings': <Object?>[
          <String, dynamic>{'buildingKey': 'b', 'sortOrder': 0},
        ],
        'floors': <Object?>[
          <String, dynamic>{
            'floorKey': 'f',
            'buildingKey': 'b',
            'level': 1,
            'svgAsset': 'assets/maps/x.svg',
            'viewBox': <String, dynamic>{
              'minX': 0,
              'minY': 0,
              'width': 10,
              'height': 10,
            },
            'sortOrder': 0,
          },
        ],
        'rooms': <Object?>[
          <String, dynamic>{
            'roomKey': 'ok',
            'roomNumber': 'A.1',
            'buildingKey': 'b',
            'floorKey': 'f',
            'roomType': 'office',
            'svgElementId': 'room-ok',
            'focus': <String, dynamic>{'x': 1, 'y': 2},
            'bounds': <String, dynamic>{
              'x': 0,
              'y': 0,
              'width': 4,
              'height': 4,
            },
            'sortOrder': 0,
          },
          <String, dynamic>{'roomNumber': 'no key'},
        ],
      });

      expect(catalog, isNotNull);
      expect(catalog!.rooms, hasLength(1));
      expect(catalog.geometryFor('ok'), isNotNull);
    });
  });
}
