// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:ui' show Offset, Rect;

import '../../../core/network/json.dart';

/// The bundled, generated map catalogue.
///
/// It is produced by `packages/campus-map` and ships as an asset, so the app
/// never parses the canonical drawing at runtime to discover its structure.
/// It carries GEOMETRY and stable keys only — every display name comes from the
/// Campus API per locale, so nothing here needs translating.

class MapBuilding {
  const MapBuilding({required this.buildingKey, required this.sortOrder});

  final String buildingKey;
  final int sortOrder;

  static MapBuilding? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    final String? key = asString(map?['buildingKey']);
    if (key == null) return null;
    return MapBuilding(
      buildingKey: key,
      sortOrder: asInt(map?['sortOrder']) ?? 0,
    );
  }
}

class MapFloor {
  const MapFloor({
    required this.floorKey,
    required this.buildingKey,
    required this.level,
    required this.svgAsset,
    required this.viewBox,
    required this.sortOrder,
  });

  final String floorKey;
  final String buildingKey;
  final int level;
  final String svgAsset;
  final Rect viewBox;
  final int sortOrder;

  static MapFloor? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? floorKey = asString(map['floorKey']);
    final String? buildingKey = asString(map['buildingKey']);
    final String? svgAsset = asString(map['svgAsset']);
    final Rect? viewBox = _rectFromJson(map['viewBox']);
    if (floorKey == null ||
        buildingKey == null ||
        svgAsset == null ||
        viewBox == null) {
      return null;
    }
    return MapFloor(
      floorKey: floorKey,
      buildingKey: buildingKey,
      level: asInt(map['level']) ?? 0,
      svgAsset: svgAsset,
      viewBox: viewBox,
      sortOrder: asInt(map['sortOrder']) ?? 0,
    );
  }
}

class MapRoomGeometry {
  const MapRoomGeometry({
    required this.roomKey,
    required this.buildingKey,
    required this.floorKey,
    required this.svgElementId,
    required this.focus,
    required this.bounds,
  });

  final String roomKey;
  final String buildingKey;
  final String floorKey;
  final String svgElementId;

  /// The point the view centres on when this room is selected.
  final Offset focus;

  /// The room outline, used to draw the highlight and to frame the view.
  final Rect bounds;

  static MapRoomGeometry? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? roomKey = asString(map['roomKey']);
    final String? floorKey = asString(map['floorKey']);
    final String? svgElementId = asString(map['svgElementId']);
    final Rect? bounds = _boundsFromJson(map['bounds']);
    final Offset? focus = _offsetFromJson(map['focus']);
    if (roomKey == null ||
        floorKey == null ||
        svgElementId == null ||
        bounds == null ||
        focus == null) {
      return null;
    }
    return MapRoomGeometry(
      roomKey: roomKey,
      buildingKey: asString(map['buildingKey']) ?? '',
      floorKey: floorKey,
      svgElementId: svgElementId,
      focus: focus,
      bounds: bounds,
    );
  }
}

class MapCatalog {
  MapCatalog({
    required this.schemaVersion,
    required this.mapVersion,
    required this.buildings,
    required this.floors,
    required List<MapRoomGeometry> rooms,
  }) : rooms = List<MapRoomGeometry>.unmodifiable(rooms),
       _roomsByKey = <String, MapRoomGeometry>{
         for (final MapRoomGeometry room in rooms) room.roomKey: room,
       },
       _floorsByKey = <String, MapFloor>{
         for (final MapFloor floor in floors) floor.floorKey: floor,
       };

  static const int supportedSchemaVersion = 1;

  final int schemaVersion;
  final String mapVersion;
  final List<MapBuilding> buildings;
  final List<MapFloor> floors;
  final List<MapRoomGeometry> rooms;

  final Map<String, MapRoomGeometry> _roomsByKey;
  final Map<String, MapFloor> _floorsByKey;

  /// Geometry for a room, or `null` when the bundled map does not know it.
  ///
  /// A `null` here is a normal, expected state: the API may serve a room the
  /// bundled map predates. The UI then shows the text and disables the map
  /// action rather than failing.
  MapRoomGeometry? geometryFor(String roomKey) => _roomsByKey[roomKey];

  MapFloor? floor(String floorKey) => _floorsByKey[floorKey];

  /// Floors of one building, in display order.
  List<MapFloor> floorsOf(String buildingKey) =>
      floors
          .where((MapFloor floor) => floor.buildingKey == buildingKey)
          .toList()
        ..sort((MapFloor a, MapFloor b) {
          final int order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.level.compareTo(b.level);
        });

  /// Whether the bundled map matches what the server describes.
  ///
  /// An absent or empty server version is treated as compatible: the per-room
  /// geometry lookup is the real safety net, and refusing to draw the map
  /// because a version string is missing would be worse than showing it.
  bool supportsMapVersion(String? serverMapVersion) {
    if (serverMapVersion == null || serverMapVersion.isEmpty) return true;
    return serverMapVersion == mapVersion;
  }

  static MapCatalog? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;

    final List<MapRoomGeometry> rooms = asList(
      map['rooms'],
    ).map(MapRoomGeometry.fromJson).whereType<MapRoomGeometry>().toList();
    if (rooms.isEmpty) return null;

    final List<MapFloor> floors = asList(
      map['floors'],
    ).map(MapFloor.fromJson).whereType<MapFloor>().toList();
    if (floors.isEmpty) return null;

    return MapCatalog(
      schemaVersion: asInt(map['schemaVersion']) ?? supportedSchemaVersion,
      mapVersion: asString(map['mapVersion']) ?? '',
      buildings:
          asList(
            map['buildings'],
          ).map(MapBuilding.fromJson).whereType<MapBuilding>().toList()..sort(
            (MapBuilding a, MapBuilding b) =>
                a.sortOrder.compareTo(b.sortOrder),
          ),
      floors: floors
        ..sort((MapFloor a, MapFloor b) => a.sortOrder.compareTo(b.sortOrder)),
      rooms: rooms,
    );
  }
}

Rect? _rectFromJson(Object? json) {
  final Map<String, dynamic>? map = asJsonMap(json);
  if (map == null) return null;
  final double? minX = asDouble(map['minX']);
  final double? minY = asDouble(map['minY']);
  final double? width = asDouble(map['width']);
  final double? height = asDouble(map['height']);
  if (minX == null || minY == null || width == null || height == null) {
    return null;
  }
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(minX, minY, width, height);
}

Rect? _boundsFromJson(Object? json) {
  final Map<String, dynamic>? map = asJsonMap(json);
  if (map == null) return null;
  final double? x = asDouble(map['x']);
  final double? y = asDouble(map['y']);
  final double? width = asDouble(map['width']);
  final double? height = asDouble(map['height']);
  if (x == null || y == null || width == null || height == null) return null;
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(x, y, width, height);
}

Offset? _offsetFromJson(Object? json) {
  final Map<String, dynamic>? map = asJsonMap(json);
  if (map == null) return null;
  final double? x = asDouble(map['x']);
  final double? y = asDouble(map['y']);
  if (x == null || y == null) return null;
  return Offset(x, y);
}
