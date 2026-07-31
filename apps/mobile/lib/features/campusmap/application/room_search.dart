// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import '../domain/room.dart';

/// Local search over the room catalogue.
///
/// The catalogue is small and fully cached, so searching happens on the device
/// — no request per keystroke, and it keeps working offline.

/// Folds a room number or query into a comparable form.
///
/// People write `B.201`, `B 201` and `B201` for the same room, so every
/// separator is removed before comparing. Letters are kept as they are, so
/// umlauts still match.
String normalizeRoomQuery(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int codeUnit in input.toLowerCase().runes) {
    final String char = String.fromCharCode(codeUnit);
    // Anything that is not a letter or digit is a separator here.
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Match quality, lower is better. Keeps ranking readable and testable.
enum _Rank { exactNumber, numberPrefix, displayName, location, none }

_Rank _rankOf(Room room, String query) {
  final String number = normalizeRoomQuery(room.roomNumber);
  if (number == query) return _Rank.exactNumber;
  if (number.startsWith(query)) return _Rank.numberPrefix;

  final String displayName = normalizeRoomQuery(room.displayName ?? '');
  if (displayName.isNotEmpty && displayName.contains(query)) {
    return _Rank.displayName;
  }

  final String location = normalizeRoomQuery(
    '${room.buildingName} ${room.floorName}',
  );
  if (location.contains(query)) return _Rank.location;

  return _Rank.none;
}

/// Returns the matching rooms, best match first.
///
/// An empty query returns the whole catalogue in its canonical order — that is
/// the normal browsing case, not "no filter applied".
List<Room> searchRooms(Iterable<Room> rooms, String query) {
  final String normalised = normalizeRoomQuery(query);
  final List<Room> all = rooms.toList()..sort(Room.compare);

  if (normalised.isEmpty) return all;

  final List<({Room room, _Rank rank})> matches = <({Room room, _Rank rank})>[];
  for (final Room room in all) {
    final _Rank rank = _rankOf(room, normalised);
    if (rank != _Rank.none) matches.add((room: room, rank: rank));
  }

  matches.sort((({Room room, _Rank rank}) a, ({Room room, _Rank rank}) b) {
    final int byRank = a.rank.index.compareTo(b.rank.index);
    return byRank != 0 ? byRank : Room.compare(a.room, b.room);
  });

  return matches.map((({Room room, _Rank rank}) match) => match.room).toList();
}
