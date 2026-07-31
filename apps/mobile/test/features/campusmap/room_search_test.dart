// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/campusmap/application/room_search.dart';
import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

Room room(
  String number, {
  String? displayName,
  String building = 'Demogebäude Nord (fiktiv)',
  String floor = '2. Obergeschoss',
  int sortOrder = 0,
}) {
  final String key =
      'demo-north-level2-${number.toLowerCase().replaceAll('.', '')}';
  return Room(
    roomKey: key,
    roomNumber: number,
    buildingKey: 'demo-north',
    buildingName: building,
    floorKey: 'demo-north-level2',
    floorLevel: 2,
    floorName: floor,
    roomType: RoomType.office,
    displayName: displayName,
    mapVersion: 'demo-1',
    sortOrder: sortOrder,
  );
}

void main() {
  group('normalisation', () {
    test('drops separators, case and whitespace', () {
      expect(normalizeRoomQuery('B.201'), 'b201');
      expect(normalizeRoomQuery('b201'), 'b201');
      expect(normalizeRoomQuery('  B 201 '), 'b201');
      expect(normalizeRoomQuery('B-201'), 'b201');
    });

    test('keeps letters of other scripts intact', () {
      expect(normalizeRoomQuery('Hörsaal'), 'hörsaal');
    });
  });

  group('searching', () {
    final List<Room> rooms = <Room>[
      room('B.201', displayName: 'Großer Hörsaal', sortOrder: 10),
      room('B.202', sortOrder: 20),
      room('B.210', sortOrder: 100),
      room('B.221', sortOrder: 210),
    ];

    test('B.201 and B201 find the same room', () {
      final List<Room> dotted = searchRooms(rooms, 'B.201');
      final List<Room> plain = searchRooms(rooms, 'B201');

      expect(dotted.first.roomKey, 'demo-north-level2-b201');
      expect(plain.first.roomKey, dotted.first.roomKey);
      expect(
        plain.map((Room r) => r.roomKey),
        dotted.map((Room r) => r.roomKey),
      );
    });

    test('an exact number outranks a prefix match', () {
      final List<Room> results = searchRooms(rooms, 'b.2');
      // "b2" is a prefix of every room here, so ordering must fall back to the
      // deterministic sort rather than to input order.
      expect(results.map((Room r) => r.roomNumber), <String>[
        'B.201',
        'B.202',
        'B.210',
        'B.221',
      ]);
    });

    test('a full number match comes first even with a high sortOrder', () {
      final List<Room> results = searchRooms(rooms, 'b221');
      expect(results.first.roomNumber, 'B.221');
    });

    test('finds a room by its editorial display name', () {
      final List<Room> results = searchRooms(rooms, 'hörsaal');
      expect(results.single.roomNumber, 'B.201');
    });

    test('finds rooms by building and floor name', () {
      expect(searchRooms(rooms, 'Demogebäude'), hasLength(4));
      expect(searchRooms(rooms, 'Obergeschoss'), hasLength(4));
    });

    test('an empty query returns everything in catalogue order', () {
      final List<Room> results = searchRooms(rooms, '   ');
      expect(results.map((Room r) => r.roomNumber), <String>[
        'B.201',
        'B.202',
        'B.210',
        'B.221',
      ]);
    });

    test('a query with no match returns nothing rather than everything', () {
      expect(searchRooms(rooms, 'zzz'), isEmpty);
    });

    test('results are stable across repeated calls', () {
      final List<String> first = searchRooms(
        rooms,
        'b2',
      ).map((Room r) => r.roomKey).toList();
      final List<String> second = searchRooms(
        rooms,
        'b2',
      ).map((Room r) => r.roomKey).toList();
      expect(second, first);
    });
  });

  group('parsing', () {
    test('reads the API shape', () {
      final Room? parsed = Room.fromJson(<String, dynamic>{
        'roomKey': 'demo-north-level2-b201',
        'roomNumber': 'B.201',
        'buildingKey': 'demo-north',
        'buildingName': 'Demogebäude Nord (fiktiv)',
        'floorKey': 'demo-north-level2',
        'floorLevel': 2,
        'floorName': '2. Obergeschoss',
        'roomType': 'lecture',
        'displayName': 'Großer Hörsaal',
        'description': 'Beschreibung',
        'mapVersion': 'demo-1',
        'sortOrder': 10,
      });

      expect(parsed, isNotNull);
      expect(parsed!.roomType, RoomType.lecture);
      expect(parsed.displayName, 'Großer Hörsaal');
      expect(parsed.floorLevel, 2);
    });

    test('maps an unknown roomType to a safe fallback instead of throwing', () {
      final Room? parsed = Room.fromJson(<String, dynamic>{
        'roomKey': 'x',
        'roomNumber': 'X.1',
        'roomType': 'wellness-area',
      });
      expect(parsed!.roomType, RoomType.unknown);
    });

    test('drops an entry without a roomKey', () {
      expect(Room.fromJson(<String, dynamic>{'roomNumber': 'X.1'}), isNull);
      expect(
        Room.listFromJson(<Object?>[
          <String, dynamic>{'roomNumber': 'X'},
        ]),
        isEmpty,
      );
    });

    test('sorts a parsed list deterministically', () {
      final List<Room> parsed = Room.listFromJson(<Object?>[
        <String, dynamic>{
          'roomKey': 'b',
          'roomNumber': 'B.202',
          'sortOrder': 20,
        },
        <String, dynamic>{
          'roomKey': 'a',
          'roomNumber': 'B.201',
          'sortOrder': 10,
        },
      ]);
      expect(parsed.map((Room r) => r.roomKey), <String>['a', 'b']);
    });
  });
}
