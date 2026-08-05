// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'moodle_course.dart';

/// Folds a string down to something two spellings of the same word share.
///
/// Case, the German umlauts and the common Latin diacritics all collapse, so
/// "Prüfung", "PRUEFUNG" and "prufung" match each other. Deliberately not a
/// full Unicode normalisation: this runs on every keystroke over the whole
/// course list, and the cases below are the ones a course title actually has.
String normaliseMoodleTerm(String value) {
  final StringBuffer out = StringBuffer();
  for (final int rune in value.toLowerCase().runes) {
    switch (rune) {
      case 0xE4: // ä
        out.write('ae');
      case 0xF6: // ö
        out.write('oe');
      case 0xFC: // ü
        out.write('ue');
      case 0xDF: // ß
        out.write('ss');
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

/// Filters the already-loaded courses.
///
/// **Purely local.** The list comes from the encrypted on-device cache, and no
/// keystroke may turn into a request — neither to Moodle nor, obviously, to a
/// Campus Köthen backend, which must never see Moodle data at all.
///
/// An empty or whitespace-only term returns the list unchanged rather than
/// nothing: an empty search field is not a filter.
List<MoodleCourse> searchMoodleCourses(
  Iterable<MoodleCourse> courses,
  String term,
) {
  final String needle = normaliseMoodleTerm(term);
  if (needle.isEmpty) return courses.toList(growable: false);

  bool matches(MoodleCourse course) =>
      normaliseMoodleTerm(course.fullName).contains(needle) ||
      normaliseMoodleTerm(course.shortName).contains(needle) ||
      normaliseMoodleTerm(course.summary).contains(needle);

  return courses.where(matches).toList(growable: false);
}
