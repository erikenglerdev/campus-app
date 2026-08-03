// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/today/domain/day_phase.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 5, 12, hour, minute);

void main() {
  group('day phase', () {
    test('maps the clock onto the phases of a teaching day', () {
      expect(TeachingDay.phaseAt(_at(2)), DayPhase.night);
      expect(TeachingDay.phaseAt(_at(6)), DayPhase.earlyMorning);
      expect(TeachingDay.phaseAt(_at(9)), DayPhase.daytime);
      expect(TeachingDay.phaseAt(_at(17, 59)), DayPhase.daytime);
      expect(TeachingDay.phaseAt(_at(19)), DayPhase.evening);
      expect(TeachingDay.phaseAt(_at(23)), DayPhase.night);
    });

    test('only the night looks ahead to the next day', () {
      expect(DayPhase.night.prefersNextDay, isTrue);
      for (final DayPhase phase in <DayPhase>[
        DayPhase.earlyMorning,
        DayPhase.daytime,
        DayPhase.evening,
      ]) {
        expect(phase.prefersNextDay, isFalse);
      }
    });

    test('late in the evening the dashboard describes tomorrow', () {
      // Showing an empty "today" at half past eleven would be correct and
      // useless at the same time.
      expect(TeachingDay.focusDate(_at(23, 30)), DateTime(2026, 5, 13));
      expect(TeachingDay.focusDate(_at(9)), DateTime(2026, 5, 12));
      expect(TeachingDay.focusDate(_at(19)), DateTime(2026, 5, 12));
    });

    test('the focus date is a date, with no time component left on it', () {
      final DateTime focus = TeachingDay.focusDate(_at(14, 37));
      expect(focus.hour, 0);
      expect(focus.minute, 0);
      expect(focus.second, 0);
    });

    test('an ongoing slot includes its start but not its end', () {
      final DateTime start = _at(10);
      final DateTime end = _at(11, 30);
      expect(TeachingDay.isOngoing(start, start, end), isTrue);
      expect(TeachingDay.isOngoing(_at(10, 45), start, end), isTrue);
      expect(
        TeachingDay.isOngoing(end, start, end),
        isFalse,
        reason: 'a lecture is over the moment it ends',
      );
      expect(TeachingDay.isOngoing(_at(9, 59), start, end), isFalse);
    });
  });
}
