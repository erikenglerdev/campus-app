// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:meta/meta.dart';

import '../../contacts/data/contact_search_models.dart';
import '../../contacts/domain/contact_search.dart';
import '../domain/room.dart';
import '../domain/room_number.dart';

export '../domain/room_number.dart' show normalizeRoomQuery;

/// Local search over the room catalogue.
///
/// The catalogue is small and fully cached, so searching happens on the device
/// — no request per keystroke, and it keeps working offline. The same is true
/// of the contact index it can search alongside: loaded once, folded into a
/// lookup, then used from memory.

/// Why a room is in the results, best first.
///
/// The order is the ranking: an exact room number always beats a fragment of
/// one, and a room found only through the person sitting in it comes last —
/// it is the least direct answer to what was typed.
enum RoomMatchReason {
  exactNumber,
  numberPrefix,
  numberContains,
  displayName,
  location,
  contact,
}

/// One search result: the room, and what made it match.
///
/// A record rather than a bare [Room] because "why is this here" is part of
/// the answer — a room found through a person is only understandable when the
/// person is named next to it.
@immutable
class RoomSearchHit {
  const RoomSearchHit({required this.room, required this.reason, this.context});

  final Room room;
  final RoomMatchReason reason;

  /// The matched person and their area, e.g. `Max Mustermann · Prüfungsamt`.
  /// `null` for every reason that speaks for itself.
  final String? context;

  bool get isContactMatch => reason == RoomMatchReason.contact;
}

/// Which rooms a person or an area occupies, and under whose name.
///
/// Built once from the contact index — searching the raw index per keystroke
/// would walk every area, every person and every description again for each
/// letter typed.
@immutable
class ContactRoomIndex {
  const ContactRoomIndex(this._entries);

  const ContactRoomIndex.empty() : _entries = const <_ContactRoomEntry>[];

  final List<_ContactRoomEntry> _entries;

  bool get isEmpty => _entries.isEmpty;

  /// Folds the public contact index into one flat list of room references.
  ///
  /// Only fields the index already delivers publicly are searchable: nothing
  /// here reaches for data the endpoint deliberately leaves out.
  static ContactRoomIndex fromAreas(Iterable<ContactSearchArea> areas) {
    final List<_ContactRoomEntry> entries = <_ContactRoomEntry>[];

    for (final ContactSearchArea area in areas) {
      final List<String> areaTerms = <String>[
        area.name,
        area.shortDescription,
        area.descriptionText,
      ];

      for (final SearchRoom room in area.rooms) {
        entries.add(
          _ContactRoomEntry(
            roomKey: room.roomKey,
            label: area.name,
            terms: <String>[
              ...areaTerms,
              room.roomNumber,
              room.displayName ?? '',
            ],
          ),
        );
      }

      for (final ContactSearchPerson person in area.persons) {
        for (final SearchRoom room in person.rooms) {
          entries.add(
            _ContactRoomEntry(
              roomKey: room.roomKey,
              // "Max Mustermann · Prüfungsamt": the person and where they sit.
              label: '${person.name} · ${area.name}',
              terms: <String>[
                person.name,
                person.role ?? '',
                person.description ?? '',
                area.name,
                room.roomNumber,
                room.displayName ?? '',
              ],
            ),
          );
        }
      }
    }

    return ContactRoomIndex(List<_ContactRoomEntry>.unmodifiable(entries));
  }

  /// The first matching label per room key.
  ///
  /// One entry per room even when several people match — the result list is
  /// about rooms, and the same room three times is noise, not information.
  Map<String, String> labelsFor(String query) {
    if (_entries.isEmpty || query.trim().isEmpty) {
      return const <String, String>{};
    }
    final ContactTerm needle = ContactTerm(query);
    if (needle.isEmpty) return const <String, String>{};

    final Map<String, String> byRoom = <String, String>{};
    for (final _ContactRoomEntry entry in _entries) {
      if (byRoom.containsKey(entry.roomKey)) continue;
      if (entry.matches(needle)) byRoom[entry.roomKey] = entry.label;
    }
    return byRoom;
  }
}

@immutable
class _ContactRoomEntry {
  const _ContactRoomEntry({
    required this.roomKey,
    required this.label,
    required this.terms,
  });

  final String roomKey;
  final String label;
  final List<String> terms;

  bool matches(ContactTerm needle) =>
      terms.any((String term) => term.isNotEmpty && needle.matches(term));
}

RoomMatchReason? _reasonFor(Room room, String query) {
  final String number = normalizeRoomQuery(room.roomNumber);
  // Typing just the digits is the everyday case — a timetable says "202", the
  // sign on the door says "B.202" — so that counts as naming the room exactly,
  // not as a fragment. Otherwise "21" would rank B.210 above B.21.
  final String bare = bareRoomNumber(number);

  if (number == query || bare == query) return RoomMatchReason.exactNumber;
  if (number.startsWith(query) || bare.startsWith(query)) {
    return RoomMatchReason.numberPrefix;
  }
  if (number.contains(query)) return RoomMatchReason.numberContains;

  final String displayName = normalizeRoomQuery(room.displayName ?? '');
  if (displayName.isNotEmpty && displayName.contains(query)) {
    return RoomMatchReason.displayName;
  }

  final String location = normalizeRoomQuery(
    '${room.buildingName} ${room.floorName}',
  );
  if (location.contains(query)) return RoomMatchReason.location;

  return null;
}

/// Returns the matching rooms with their reason, best match first.
///
/// An empty query returns the whole catalogue in its canonical order — that is
/// the normal browsing case, not "no filter applied".
///
/// [contacts] is optional and additive: while the index is loading, or if it
/// failed, the room search behaves exactly as it does without it. A room found
/// both directly and through a person keeps its **direct** reason, which is
/// the more specific answer.
List<RoomSearchHit> searchRoomHits(
  Iterable<Room> rooms,
  String query, {
  ContactRoomIndex contacts = const ContactRoomIndex.empty(),
}) {
  final String normalised = normalizeRoomQuery(query);
  final List<Room> all = rooms.toList()..sort(Room.compare);

  if (normalised.isEmpty) {
    return <RoomSearchHit>[
      for (final Room room in all)
        RoomSearchHit(room: room, reason: RoomMatchReason.exactNumber),
    ];
  }

  final Map<String, String> contactLabels = contacts.labelsFor(query);

  final List<RoomSearchHit> matches = <RoomSearchHit>[];
  for (final Room room in all) {
    final RoomMatchReason? direct = _reasonFor(room, normalised);
    if (direct != null) {
      matches.add(RoomSearchHit(room: room, reason: direct));
      continue;
    }
    final String? label = contactLabels[room.roomKey];
    if (label != null) {
      matches.add(
        RoomSearchHit(
          room: room,
          reason: RoomMatchReason.contact,
          context: label,
        ),
      );
    }
  }

  matches.sort((RoomSearchHit a, RoomSearchHit b) {
    final int byReason = a.reason.index.compareTo(b.reason.index);
    return byReason != 0 ? byReason : Room.compare(a.room, b.room);
  });

  return matches;
}

/// Rooms only, for callers that do not care why something matched.
List<Room> searchRooms(
  Iterable<Room> rooms,
  String query, {
  ContactRoomIndex contacts = const ContactRoomIndex.empty(),
}) => searchRoomHits(
  rooms,
  query,
  contacts: contacts,
).map((RoomSearchHit hit) => hit.room).toList();
