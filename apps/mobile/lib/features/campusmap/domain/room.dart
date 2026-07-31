// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import '../../../core/network/json.dart';

/// Stable technical room categories.
///
/// The Campus API sends a technical key, never a localised label, so a new
/// category on the server can never leak an untranslated German word into the
/// UI. [RoomType.unknown] keeps an unrecognised value from breaking the screen.
enum RoomType {
  lecture,
  seminar,
  office,
  lab,
  meeting,
  service,
  unknown;

  static RoomType fromKey(String? key) {
    switch (key) {
      case 'lecture':
        return RoomType.lecture;
      case 'seminar':
        return RoomType.seminar;
      case 'office':
        return RoomType.office;
      case 'lab':
        return RoomType.lab;
      case 'meeting':
        return RoomType.meeting;
      case 'service':
        return RoomType.service;
      default:
        return RoomType.unknown;
    }
  }
}

/// One room of the fictional demo campus map, as served by `/v1/rooms`.
///
/// Editorial fields are optional; the UI hides what is missing instead of
/// rendering an empty row.
class Room {
  const Room({
    required this.roomKey,
    required this.roomNumber,
    required this.buildingKey,
    required this.buildingName,
    required this.floorKey,
    required this.floorLevel,
    required this.floorName,
    required this.roomType,
    required this.mapVersion,
    required this.sortOrder,
    this.displayName,
    this.description,
  });

  final String roomKey;
  final String roomNumber;

  final String buildingKey;
  final String buildingName;

  final String floorKey;
  final int floorLevel;
  final String floorName;

  final RoomType roomType;

  final String? displayName;
  final String? description;

  final String mapVersion;
  final int sortOrder;

  /// What a list row leads with: the editorial name when there is one.
  String get primaryLabel => displayName ?? roomNumber;

  static Room? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? roomKey = asString(map['roomKey']);
    if (roomKey == null) return null;

    return Room(
      roomKey: roomKey,
      roomNumber: asString(map['roomNumber']) ?? roomKey,
      buildingKey: asString(map['buildingKey']) ?? '',
      buildingName: asString(map['buildingName']) ?? '',
      floorKey: asString(map['floorKey']) ?? '',
      floorLevel: asInt(map['floorLevel']) ?? 0,
      floorName: asString(map['floorName']) ?? '',
      roomType: RoomType.fromKey(asString(map['roomType'])),
      displayName: asString(map['displayName']),
      description: asString(map['description']),
      mapVersion: asString(map['mapVersion']) ?? '',
      sortOrder: asInt(map['sortOrder']) ?? 0,
    );
  }

  static List<Room> listFromJson(Object? json) =>
      asList(json).map(Room.fromJson).whereType<Room>().toList()..sort(compare);

  /// The one ordering used everywhere, so lists never reshuffle between builds.
  static int compare(Room a, Room b) {
    final int order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    final int number = a.roomNumber.compareTo(b.roomNumber);
    return number != 0 ? number : a.roomKey.compareTo(b.roomKey);
  }
}
