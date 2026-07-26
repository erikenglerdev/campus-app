// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/features/moodle/application/moodle_providers.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_account.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_cache.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_course.dart';
import 'package:campus_koethen/features/moodle/presentation/moodle_screen.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_moodle.dart';
import '../../support/pump_app.dart';

List<Override> _overrides({
  required FakeMoodleApiClient api,
  required InMemoryMoodleTokenStore tokens,
  required InMemoryMoodleCacheStore cache,
  required MutableClock clock,
}) => <Override>[
  moodleApiClientProvider.overrideWithValue(api),
  moodleTokenStoreProvider.overrideWithValue(tokens),
  moodleCacheStoreProvider.overrideWithValue(cache),
  moodleClockProvider.overrideWithValue(clock),
];

void main() {
  final DateTime t0 = DateTime.utc(2026, 7, 26, 12);

  testWidgets('shows the connect screen when disconnected', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: InMemoryMoodleTokenStore(),
        cache: InMemoryMoodleCacheStore(),
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    // The connect gate is shown, not the overview.
    expect(find.text('Mit Moodle verbinden'), findsOneWidget);
    expect(find.text('Meine Kurse'), findsNothing);
  });

  testWidgets('shows cached courses when connected', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Beispielkurs Informatik'),
      ]
      // A recent attempt suppresses the automatic sync in this test.
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beispielkurs Informatik'), findsOneWidget);
  });
}
