// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/search/domain/search_index.dart';
import 'package:campus_koethen/features/search/domain/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

SearchEntry _entry(
  String title, {
  SearchCategory category = SearchCategory.room,
  String? subtitle,
  List<String> keywords = const <String>[],
}) => SearchEntry(
  category: category,
  title: title,
  route: '/x/$title',
  subtitle: subtitle,
  keywords: keywords,
);

void main() {
  group('normalisation', () {
    test('folds case, diacritics and punctuation', () {
      expect(normalizeSearchTerm('B.201'), 'b201');
      expect(normalizeSearchTerm('b201'), 'b201');
      expect(normalizeSearchTerm('Gemüsepfanne'), 'gemuesepfanne');
      expect(normalizeSearchTerm('Straße'), 'strasse');
      expect(normalizeSearchTerm('  '), '');
    });

    test('B.201 and b201 are the same search', () {
      // The room search already worked this way; a second, different notion of
      // "the same" would be worse than none.
      final List<SearchEntry> entries = <SearchEntry>[_entry('B.201')];
      expect(searchEntries(entries, 'b201'), hasLength(1));
      expect(searchEntries(entries, 'B.201'), hasLength(1));
      expect(searchEntries(entries, 'b.2'), hasLength(1));
    });
  });

  group('matching', () {
    test('a blank query finds nothing at all', () {
      expect(searchEntries(<SearchEntry>[_entry('B.201')], ''), isEmpty);
      expect(searchEntries(<SearchEntry>[_entry('B.201')], '   '), isEmpty);
    });

    test('matches title, subtitle and keywords', () {
      final List<SearchEntry> entries = <SearchEntry>[
        _entry('Raum', subtitle: 'Demogebäude Nord'),
        _entry('Anderer', keywords: <String>['stichwort']),
      ];
      expect(searchEntries(entries, 'demogebaeude'), hasLength(1));
      expect(searchEntries(entries, 'stichwort'), hasLength(1));
    });

    test('an unrelated query finds nothing', () {
      expect(searchEntries(<SearchEntry>[_entry('B.201')], 'zzz'), isEmpty);
    });
  });

  group('ranking', () {
    test('exact beats prefix beats word-prefix beats contains', () {
      final List<SearchEntry> entries = <SearchEntry>[
        _entry('Vorlesung Analysis'), // word prefix on "Analysis"
        _entry('Analysis'), // exact
        _entry('Analysisübung'), // prefix
        _entry('Realanalysisfoo'), // contains
      ];
      final List<SearchResult> hits = searchEntries(entries, 'analysis');

      expect(hits.map((SearchResult r) => r.title), <String>[
        'Analysis',
        'Analysisübung',
        'Vorlesung Analysis',
        'Realanalysisfoo',
      ]);
      expect(hits.first.rank, SearchRank.exact);
    });

    test('equal ranks are ordered by category, then stably by name', () {
      // Stability matters: results must not shuffle between keystrokes.
      final List<SearchEntry> entries = <SearchEntry>[
        _entry('Test', category: SearchCategory.meal),
        _entry('Test', category: SearchCategory.section),
        _entry('Test', category: SearchCategory.room),
      ];
      final List<SearchResult> hits = searchEntries(entries, 'test');
      expect(hits.map((SearchResult r) => r.category), <SearchCategory>[
        SearchCategory.section,
        SearchCategory.room,
        SearchCategory.meal,
      ]);
    });

    test('the same query twice gives the same order', () {
      final List<SearchEntry> entries = <SearchEntry>[
        _entry('Beta', category: SearchCategory.room),
        _entry('Alpha', category: SearchCategory.room),
      ];
      expect(
        searchEntries(entries, 'a').map((SearchResult r) => r.title),
        searchEntries(entries, 'a').map((SearchResult r) => r.title),
      );
    });
  });

  group('the categories the search may cover', () {
    test('contain no personal service at all', () {
      // The guarantee is structural: there is no category a mail message, a
      // grade or a Moodle item could even be filed under.
      final Set<String> names = SearchCategory.values
          .map((SearchCategory c) => c.name.toLowerCase())
          .toSet();
      for (final String forbidden in <String>[
        'mail',
        'message',
        'grade',
        'moodle',
        'submission',
        'credential',
      ]) {
        expect(
          names,
          isNot(contains(forbidden)),
          reason: '"$forbidden" must never be a search category',
        );
      }
    });

    test('cover exactly the public sources the product asked for', () {
      expect(SearchCategory.values.toSet(), <SearchCategory>{
        SearchCategory.section,
        SearchCategory.news,
        SearchCategory.event,
        SearchCategory.timetable,
        SearchCategory.room,
        SearchCategory.contact,
        SearchCategory.meal,
      });
    });
  });
}
