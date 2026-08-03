// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/app/navigation_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation config', () {
    test('the default bar is Today, three middles and More', () {
      const NavigationConfig config = NavigationConfig.defaults;
      expect(config.destinations.first, AppSection.today);
      expect(config.destinations.last, AppSection.more);
      expect(config.destinations.length, 5);
      expect(config.middle, <AppSection>[
        AppSection.calendar,
        AppSection.canteen,
        AppSection.news,
      ]);
    });

    test('Today and More can never be pushed out of their slots', () {
      // Even asked for explicitly, the fixed entries must not become middles:
      // "More" is how every other area stays reachable, and losing it would
      // strand whole parts of the app.
      final NavigationConfig config = NavigationConfig.fromStorage(<String>[
        AppSection.more.storageValue,
        AppSection.today.storageValue,
        AppSection.mail.storageValue,
      ]);
      expect(config.middle, isNot(contains(AppSection.today)));
      expect(config.middle, isNot(contains(AppSection.more)));
      expect(config.destinations.first, AppSection.today);
      expect(config.destinations.last, AppSection.more);
      expect(config.destinations.length, 5);
    });

    test('duplicates are collapsed and the gap is filled', () {
      final NavigationConfig config = NavigationConfig.fromStorage(<String>[
        AppSection.news.storageValue,
        AppSection.news.storageValue,
        AppSection.news.storageValue,
      ]);
      expect(config.middle.toSet().length, 3, reason: 'no duplicate targets');
      expect(config.middle.first, AppSection.news);
      expect(config.middle.length, 3);
    });

    test('unknown identifiers are dropped rather than crashing', () {
      final NavigationConfig config = NavigationConfig.fromStorage(<String>[
        'a-section-that-was-removed',
        AppSection.todos.storageValue,
        '',
      ]);
      expect(config.middle, contains(AppSection.todos));
      expect(config.middle.length, 3);
      expect(config.isValid, isTrue);
    });

    test('too few or too many entries are brought back to exactly three', () {
      expect(NavigationConfig.fromStorage(<String>[]).middle.length, 3);
      expect(
        NavigationConfig.fromStorage(<String>[
          AppSection.mail.storageValue,
        ]).middle.length,
        3,
      );
      expect(
        NavigationConfig.fromStorage(<String>[
          AppSection.mail.storageValue,
          AppSection.todos.storageValue,
          AppSection.grades.storageValue,
          AppSection.contacts.storageValue,
          AppSection.campusMap.storageValue,
        ]).middle,
        <AppSection>[AppSection.mail, AppSection.todos, AppSection.grades],
        reason: 'the first three chosen entries win',
      );
    });

    test('a null store — first launch — yields the defaults', () {
      expect(NavigationConfig.fromStorage(null), NavigationConfig.defaults);
    });

    test('round-trips through storage', () {
      final NavigationConfig config = NavigationConfig.of(<AppSection>[
        AppSection.mail,
        AppSection.campusMap,
        AppSection.todos,
      ]);
      expect(NavigationConfig.fromStorage(config.toStorage()), config);
    });

    test('every destination has a route and they are all distinct', () {
      const NavigationConfig config = NavigationConfig.defaults;
      final Set<String> routes = <String>{};
      for (final AppSection section in config.destinations) {
        expect(section.route, isNotEmpty);
        expect(
          routes.add(section.route),
          isTrue,
          reason: 'two tabs must never share a route',
        );
      }
    });

    test('the index of a route is found, and unknown routes report -1', () {
      const NavigationConfig config = NavigationConfig.defaults;
      expect(config.indexOfRoute(AppRoutesProbe.today), 0);
      expect(config.indexOfRoute('/does-not-exist'), -1);
    });
  });

  group('configurable catalogue', () {
    test('offers the areas the product asks for, minus the fixed ones', () {
      final List<AppSection> offered = AppSection.configurable;
      expect(offered, isNot(contains(AppSection.today)));
      expect(offered, isNot(contains(AppSection.more)));
      for (final AppSection expected in <AppSection>[
        AppSection.calendar,
        AppSection.canteen,
        AppSection.news,
        AppSection.moodle,
        AppSection.mail,
        AppSection.todos,
        AppSection.campusMap,
        AppSection.contacts,
        AppSection.grades,
      ]) {
        expect(offered, contains(expected));
      }
    });

    test('storage identifiers are unique', () {
      final Set<String> seen = <String>{};
      for (final AppSection section in AppSection.values) {
        expect(seen.add(section.storageValue), isTrue);
      }
    });

    test('the personal services are exactly mail, grades and Moodle', () {
      expect(
        AppSection.values.where((AppSection s) => s.isPersonalService).toSet(),
        <AppSection>{AppSection.mail, AppSection.grades, AppSection.moodle},
      );
    });
  });
}

/// Route literals the test asserts against, kept separate so a typo in the
/// test cannot silently pass by reading the value under test.
abstract final class AppRoutesProbe {
  static const String today = '/today';
}
