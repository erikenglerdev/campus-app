// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Proves that the global search cannot reach personal data.
///
/// The product rule is that mail, grades and Moodle never appear in the public
/// search. A reviewer can promise that; this test makes it structural, so
/// adding such an import is a failing build rather than a comment someone
/// might miss in review.
library;

import 'dart:io';

import 'package:campus_koethen/features/search/domain/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Libraries the search must never depend on, directly or by re-export.
const List<String> _forbiddenImports = <String>[
  'features/mail/',
  'features/grades/',
  'features/moodle/',
  'flutter_secure_storage',
];

/// Every file that makes up the search feature.
List<File> _searchSources() {
  final Directory dir = Directory('lib/features/search');
  expect(dir.existsSync(), isTrue, reason: 'the search feature must exist');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('the search cannot see personal data', () {
    test('no file in the feature imports a personal service', () {
      final List<File> sources = _searchSources();
      expect(sources, isNotEmpty);

      for (final File file in sources) {
        final String content = file.readAsStringSync();
        for (final String forbidden in _forbiddenImports) {
          expect(
            content.contains(forbidden),
            isFalse,
            reason:
                '${file.path} references "$forbidden". Mail, grades and Moodle '
                'must never be reachable from the public search.',
          );
        }
      }
    });

    test('no search category could hold personal content', () {
      // Even with an import, there would be nowhere to put the result.
      final Set<String> names = SearchCategory.values
          .map((SearchCategory c) => c.name.toLowerCase())
          .toSet();
      expect(names, isNot(contains('mail')));
      expect(names, isNot(contains('grade')));
      expect(names, isNot(contains('moodle')));
    });

    test('the index builder sends nothing anywhere', () {
      // A server-side search would mean transmitting every keystroke. The
      // assembler must therefore contain no HTTP call of its own.
      final String assembler = File(
        'lib/features/search/application/search_providers.dart',
      ).readAsStringSync();
      for (final String networkish in <String>[
        'dio',
        'http',
        'ApiClient',
        'post(',
      ]) {
        expect(
          assembler.contains(networkish),
          isFalse,
          reason:
              'the search reads already-cached data; "$networkish" suggests it '
              'started talking to a backend',
        );
      }
    });
  });
}
