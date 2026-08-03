// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'search_result.dart';

/// One searchable item, reduced to what matching needs.
///
/// Building the index from these rather than from feature models keeps the
/// matcher independent of every feature's shape — and makes it structurally
/// impossible to hand it a mail message, because there is no path from one to
/// the other.
class SearchEntry {
  const SearchEntry({
    required this.category,
    required this.title,
    required this.route,
    this.subtitle,
    this.keywords = const <String>[],
    this.sortKey = '',
  });

  final SearchCategory category;
  final String title;
  final String route;
  final String? subtitle;

  /// Extra terms that should match, e.g. a room number without its dot.
  final List<String> keywords;

  final String sortKey;
}

/// Normalises a query or a field for comparison.
///
/// Case- and diacritic-insensitive, and punctuation is dropped so `B.201` and
/// `b201` are the same search — the room search already worked that way and a
/// second, different notion of "the same" would be worse than none.
String normalizeSearchTerm(String value) {
  const Map<String, String> folds = <String, String>{
    'ä': 'ae',
    'ö': 'oe',
    'ü': 'ue',
    'ß': 'ss',
    'é': 'e',
    'è': 'e',
    'á': 'a',
    'à': 'a',
  };
  final StringBuffer buffer = StringBuffer();
  for (final String char in value.toLowerCase().split('')) {
    buffer.write(folds[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Ranks [entries] against [query]. Returns the empty list for a blank query.
///
/// Pure and synchronous: search runs on every keystroke, and anything that
/// touches the network or the disk here would make typing stutter.
List<SearchResult> searchEntries(Iterable<SearchEntry> entries, String query) {
  final String needle = normalizeSearchTerm(query);
  if (needle.isEmpty) return const <SearchResult>[];

  final List<SearchResult> hits = <SearchResult>[];
  for (final SearchEntry entry in entries) {
    final SearchRank? rank = _rank(entry, needle);
    if (rank == null) continue;
    hits.add(
      SearchResult(
        category: entry.category,
        title: entry.title,
        route: entry.route,
        subtitle: entry.subtitle,
        rank: rank,
        sortKey: entry.sortKey.isEmpty ? entry.title : entry.sortKey,
      ),
    );
  }

  hits.sort((SearchResult a, SearchResult b) {
    final int byRank = a.rank.index.compareTo(b.rank.index);
    if (byRank != 0) return byRank;
    final int byCategory = a.category.index.compareTo(b.category.index);
    if (byCategory != 0) return byCategory;
    return a.sortKey.toLowerCase().compareTo(b.sortKey.toLowerCase());
  });
  return List<SearchResult>.unmodifiable(hits);
}

SearchRank? _rank(SearchEntry entry, String needle) {
  SearchRank? best;
  void consider(SearchRank? rank) {
    if (rank == null) return;
    if (best == null || rank.index < best!.index) best = rank;
  }

  consider(_rankField(entry.title, needle));
  consider(_rankField(entry.subtitle ?? '', needle));
  for (final String keyword in entry.keywords) {
    consider(_rankField(keyword, needle));
  }
  return best;
}

SearchRank? _rankField(String field, String needle) {
  final String haystack = normalizeSearchTerm(field);
  if (haystack.isEmpty) return null;
  if (haystack == needle) return SearchRank.exact;
  if (haystack.startsWith(needle)) return SearchRank.prefix;
  // Word prefixes are checked on the RAW field, because normalising removes
  // the spaces that separate words.
  for (final String word in field.toLowerCase().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    if (normalizeSearchTerm(word).startsWith(needle)) {
      return SearchRank.wordPrefix;
    }
  }
  if (haystack.contains(needle)) return SearchRank.contains;
  return null;
}
