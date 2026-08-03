// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Holds the design system's promise across the whole app.
///
/// A setting that visibly changes five screens and silently does nothing on
/// twenty-seven others is worse than no setting: the user changes it, sees
/// almost no effect, and concludes the app is broken. Before this test, every
/// screen of contacts, Moodle, mail, grades and to-dos used a fixed padding
/// and ignored the density entirely.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Features whose screens must honour the display density.
const List<String> _features = <String>[
  'contacts',
  'moodle',
  'mail',
  'grades',
  'todos',
  'today',
  'requests',
  'search',
];

List<File> _screensOf(String feature) {
  final Directory dir = Directory('lib/features/$feature/presentation');
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('no screen hardcodes the outer padding the density owns', () {
    // `EdgeInsets.all(AppSpacing.lg)` as a scroll view's padding is exactly the
    // value AppMetrics.screenPadding exists to decide.
    final List<String> offenders = <String>[];

    for (final String feature in _features) {
      for (final File file in _screensOf(feature)) {
        final String content = file.readAsStringSync();
        if (content.contains('padding: const EdgeInsets.all(AppSpacing.lg),')) {
          offenders.add(file.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these screens ignore the display density and should use '
          'context.metrics.screenPadding:\n${offenders.join('\n')}',
    );
  });

  test('the features under test actually exist', () {
    // Guards against the check above passing because a rename made it look at
    // nothing at all.
    for (final String feature in _features) {
      expect(
        _screensOf(feature),
        isNotEmpty,
        reason: 'no screens found for "$feature" — has it moved?',
      );
    }
  });
}
