// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// What kind of thing a hit is.
///
/// Every value here is **public, non-sensitive** content. Mail, grades and
/// Moodle are deliberately absent and there is no value they could be mapped
/// to — the type system is the first line of the guarantee, not a convention.
enum SearchCategory {
  /// An area or function of the app itself.
  section,
  news,

  /// A public calendar event.
  event,

  /// A timetable entry.
  timetable,
  room,
  contact,
  meal,
}

/// One hit.
@immutable
class SearchResult {
  const SearchResult({
    required this.category,
    required this.title,
    required this.route,
    this.subtitle,
    this.rank = SearchRank.contains,
    this.sortKey = '',
  });

  final SearchCategory category;
  final String title;

  /// Where tapping the hit goes. Always an in-app route, never an external URL.
  final String route;

  final String? subtitle;
  final SearchRank rank;

  /// Tie-breaker within a rank, so equal matches keep a stable order instead
  /// of shuffling between keystrokes.
  final String sortKey;

  @override
  bool operator ==(Object other) =>
      other is SearchResult &&
      other.category == category &&
      other.title == title &&
      other.route == route;

  @override
  int get hashCode => Object.hash(category, title, route);

  @override
  String toString() => '${category.name}:$title';
}

/// How well a hit matched. Lower is better.
enum SearchRank {
  /// The whole field equals the query.
  exact,

  /// The field starts with the query.
  prefix,

  /// A word inside the field starts with the query.
  wordPrefix,

  /// The query appears somewhere in the field.
  contains,
}
