// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../data/contact_search_models.dart';

/// Local search over the contact index.
///
/// **Purely local.** The index is loaded once and cached; no keystroke becomes
/// a request. That is also why the API has a dedicated index endpoint at all —
/// searching over descriptions and room numbers otherwise meant one detail
/// request per area, on every letter typed.

/// One result: either an area or a person inside one.
@immutable
sealed class ContactSearchHit {
  const ContactSearchHit({required this.area, required this.context});

  /// The area to open when the result is tapped. For a person, the area they
  /// belong to — that is where their details live.
  final ContactSearchArea area;

  /// The text that matched, shown under the result so a hit on a phone number
  /// does not look like an unexplained entry.
  final String context;
}

class AreaHit extends ContactSearchHit {
  const AreaHit({required super.area, required super.context});
}

class PersonHit extends ContactSearchHit {
  const PersonHit({
    required this.person,
    required super.area,
    required super.context,
  });

  final ContactSearchPerson person;
}

/// Folds a string down to something two spellings of the same word share.
///
/// Case and the common Latin diacritics collapse. Umlauts are the awkward
/// case: somebody looking for "Prüfungsamt" may type "pruefungsamt" or
/// "prufungsamt", and no single spelling contains both. So there are two
/// foldings — [expandUmlauts] writes `ü` as `ue`, otherwise as `u` — and a
/// match is accepted when **either** agrees. Anything else would make one of
/// the two spellings silently find nothing.
String normaliseContactTerm(String value, {bool expandUmlauts = true}) {
  final StringBuffer out = StringBuffer();
  for (final int rune in value.toLowerCase().runes) {
    switch (rune) {
      case 0xE4: // ä
        out.write(expandUmlauts ? 'ae' : 'a');
      case 0xF6: // ö
        out.write(expandUmlauts ? 'oe' : 'o');
      case 0xFC: // ü
        out.write(expandUmlauts ? 'ue' : 'u');
      case 0xDF: // ß
        out.write(expandUmlauts ? 'ss' : 's');
      case 0xE0 || 0xE1 || 0xE2 || 0xE3 || 0xE5:
        out.write('a');
      case 0xE8 || 0xE9 || 0xEA || 0xEB:
        out.write('e');
      case 0xEC || 0xED || 0xEE || 0xEF:
        out.write('i');
      case 0xF2 || 0xF3 || 0xF4 || 0xF5:
        out.write('o');
      case 0xF9 || 0xFA || 0xFB:
        out.write('u');
      case 0xE7: // ç
        out.write('c');
      case 0xF1: // ñ
        out.write('n');
      default:
        out.writeCharCode(rune);
    }
  }
  return out.toString().trim();
}

/// The room-number form of a term: letters and digits only.
///
/// "B.201", "B 201", "B-201" and "b201" are the same room to everybody but a
/// string comparison, and a room number is exactly the kind of thing people
/// type without its punctuation.
String _roomForm(String value) =>
    normaliseContactTerm(value).replaceAll(RegExp('[^a-z0-9]'), '');

/// Both foldings of one string, so a match can accept either.
@immutable
class _Needle {
  _Needle(String term)
    : expanded = normaliseContactTerm(term),
      plain = normaliseContactTerm(term, expandUmlauts: false),
      room = _roomForm(term);

  final String expanded;
  final String plain;
  final String room;

  bool get isEmpty => expanded.isEmpty;

  bool matches(String haystack) =>
      normaliseContactTerm(haystack).contains(expanded) ||
      normaliseContactTerm(haystack, expandUmlauts: false).contains(plain);
}

/// Searches [index] for [term].
///
/// An empty term yields **no** results rather than everything: the screen falls
/// back to the ordinary area list, and "match everything" is not what an empty
/// search field means.
///
/// An area and one of its persons can both match; they are then two results,
/// with the area first. A matching area never drags in its persons — a hit has
/// to be a hit on its own.
List<ContactSearchHit> searchContacts(
  Iterable<ContactSearchArea> index,
  String term,
) {
  final _Needle needle = _Needle(term);
  if (needle.isEmpty) return const <ContactSearchHit>[];

  final List<ContactSearchHit> hits = <ContactSearchHit>[];

  for (final ContactSearchArea area in index) {
    final String? areaMatch = _firstMatch(
      needle,
      _areaFields(area),
      area.rooms,
    );
    if (areaMatch != null) {
      hits.add(AreaHit(area: area, context: areaMatch));
    }

    for (final ContactSearchPerson person in area.persons) {
      final String? personMatch = _firstMatch(
        needle,
        _personFields(person),
        person.rooms,
      );
      if (personMatch != null) {
        hits.add(PersonHit(person: person, area: area, context: personMatch));
      }
    }
  }

  return List<ContactSearchHit>.unmodifiable(hits);
}

/// The first field that contains the term, so the result can show *why*.
String? _firstMatch(
  _Needle needle,
  List<String?> fields,
  List<SearchRoom> rooms,
) {
  for (final String? field in fields) {
    if (field == null || field.isEmpty) continue;
    if (needle.matches(field)) return field;
  }
  for (final SearchRoom room in rooms) {
    for (final String? field in <String?>[
      room.roomNumber,
      room.displayName,
      room.buildingName,
      room.floorName,
    ]) {
      if (field == null || field.isEmpty) continue;
      if (needle.matches(field)) return field;
    }
    // The punctuation-free form only ever applies to the number itself:
    // stripping it from prose would match across word boundaries.
    if (needle.room.isNotEmpty &&
        _roomForm(room.roomNumber).contains(needle.room)) {
      return room.roomNumber;
    }
  }
  return null;
}

List<String?> _areaFields(ContactSearchArea area) => <String?>[
  area.name,
  area.shortDescription,
  area.descriptionText,
  area.generalEmail,
  area.phone,
  area.website,
  area.appointmentUrl,
  area.address,
  area.openingHours,
];

List<String?> _personFields(ContactSearchPerson person) => <String?>[
  person.name,
  person.role,
  person.description,
  person.email,
  person.phone,
  person.website,
];
