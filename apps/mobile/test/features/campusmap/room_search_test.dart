// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/campusmap/application/room_search.dart';
import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:campus_koethen/features/contacts/data/contact_search_models.dart';
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

    test('the bare number finds the room, without its building letter', () {
      // The everyday case: a timetable says "202", the sign on the door says
      // "B.202". Before substring matching this search came back empty.
      final List<Room> results = searchRooms(rooms, '202');
      expect(results.single.roomNumber, 'B.202');
    });

    test('B.202, B202, b 202 and 202 all find the same room', () {
      for (final String query in <String>['B.202', 'B202', 'b 202', '202']) {
        expect(
          searchRooms(rooms, query).first.roomKey,
          'demo-north-level2-b202',
          reason: 'query "$query"',
        );
      }
    });

    test('an exact hit is listed before a room that merely contains it', () {
      final List<Room> results = searchRooms(<Room>[
        ...rooms,
        room('B.21', sortOrder: 500),
      ], '21');

      // "B.21" is the room asked for; "B.210" and "B.221" only contain it.
      expect(results.first.roomNumber, 'B.21');
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

  group('searching through contacts', () {
    final List<Room> rooms = <Room>[
      room('B.201', sortOrder: 10),
      room('B.202', sortOrder: 20),
      room('B.301', sortOrder: 30),
    ];

    SearchRoom searchRoom(String number) => SearchRoom(
      roomKey: 'demo-north-level2-${number.toLowerCase().replaceAll('.', '')}',
      roomNumber: number,
      buildingName: 'Demogebäude Nord (fiktiv)',
      floorName: '2. Obergeschoss',
    );

    final ContactRoomIndex index = ContactRoomIndex.fromAreas(
      <ContactSearchArea>[
        ContactSearchArea(
          slug: 'demo-pruefungsamt',
          name: 'Demo-Prüfungsamt (fiktiv)',
          shortDescription: 'Beispielbereich',
          descriptionText: 'Nur zu Demonstrationszwecken.',
          rooms: <SearchRoom>[searchRoom('B.301')],
          persons: <ContactSearchPerson>[
            ContactSearchPerson(
              name: 'Björn Demoperson',
              role: 'Beispielrolle',
              rooms: <SearchRoom>[searchRoom('B.201')],
            ),
            ContactSearchPerson(
              name: 'Zweite Demoperson',
              // Deliberately the same room as the first person.
              rooms: <SearchRoom>[searchRoom('B.201')],
            ),
          ],
        ),
      ],
    );

    test('a person leads to the room they sit in', () {
      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        'Demoperson',
        contacts: index,
      );

      expect(hits.single.room.roomNumber, 'B.201');
      expect(hits.single.reason, RoomMatchReason.contact);
      // Without the name next to it, the hit is unexplainable to the reader.
      expect(hits.single.context, contains('Demoperson'));
    });

    test('umlauts in a name match either spelling', () {
      for (final String query in <String>['Björn', 'Bjoern', 'bjorn']) {
        expect(
          searchRoomHits(rooms, query, contacts: index).single.room.roomNumber,
          'B.201',
          reason: 'query "$query"',
        );
      }
    });

    test('two matching people do not list the same room twice', () {
      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        'Demoperson',
        contacts: index,
      );
      expect(hits, hasLength(1));
    });

    test('a contact point leads to its rooms and those of its people', () {
      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        'Prüfungsamt',
        contacts: index,
      );

      // Everything the contact point occupies — asking for an office by name
      // should not hide the office of the person working there.
      expect(hits.map((RoomSearchHit h) => h.room.roomNumber), <String>[
        'B.201',
        'B.301',
      ]);
      expect(hits.first.context, contains('Björn Demoperson'));
      expect(hits.last.context, 'Demo-Prüfungsamt (fiktiv)');
    });

    test('a direct room hit keeps its own reason and beats a contact hit', () {
      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        'B.201',
        contacts: index,
      );

      // The room was asked for by number, so that is why it is here — even
      // though a person in it matches nothing and the index would also know it.
      expect(hits.first.reason, RoomMatchReason.exactNumber);
      expect(hits.first.context, isNull);
    });

    test('contact hits are ranked below every direct hit', () {
      final ContactRoomIndex byNumber = ContactRoomIndex.fromAreas(
        <ContactSearchArea>[
          ContactSearchArea(
            slug: 'demo-bereich',
            name: 'Demobereich (fiktiv)',
            shortDescription: '',
            descriptionText: '',
            persons: <ContactSearchPerson>[
              // This person's description mentions B.301, so a search for
              // "202" must not pull their room above the actual B.202.
              ContactSearchPerson(
                name: 'Dritte Demoperson',
                description: 'Vertretung für Raum 202',
                rooms: <SearchRoom>[searchRoom('B.301')],
              ),
            ],
          ),
        ],
      );

      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        '202',
        contacts: byNumber,
      );

      expect(hits.map((RoomSearchHit h) => h.room.roomNumber), <String>[
        'B.202',
        'B.301',
      ]);
      expect(hits.last.reason, RoomMatchReason.contact);
    });

    test('the plain room search keeps working without a contact index', () {
      // What happens while the index loads, or after it failed: the search is
      // narrower, never broken.
      expect(searchRooms(rooms, '202').single.roomNumber, 'B.202');
      expect(searchRooms(rooms, 'Demoperson'), isEmpty);
      expect(
        searchRoomHits(
          rooms,
          'Demoperson',
          contacts: const ContactRoomIndex.empty(),
        ),
        isEmpty,
      );
    });

    test('an empty query does not drag in every contact room', () {
      final List<RoomSearchHit> hits = searchRoomHits(
        rooms,
        '',
        contacts: index,
      );
      expect(hits, hasLength(3));
      expect(hits.every((RoomSearchHit h) => h.context == null), isTrue);
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
