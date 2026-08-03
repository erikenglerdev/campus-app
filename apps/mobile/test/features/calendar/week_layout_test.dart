// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/domain/week_layout.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEntry _e(
  String id, {
  required int fromH,
  int fromM = 0,
  required int toH,
  int toM = 0,
  bool allDay = false,
}) => CalendarEntry(
  id: id,
  source: CalendarSource.timetable,
  title: id,
  start: DateTime(2026, 5, 12, fromH, fromM),
  end: DateTime(2026, 5, 12, toH, toM),
  allDay: allDay,
);

Map<String, PlacedEntry> _byId(List<PlacedEntry> placed) =>
    <String, PlacedEntry>{for (final PlacedEntry p in placed) p.entry.id: p};

void main() {
  group('grid range', () {
    test('an empty week still looks like a calendar', () {
      final GridRange range = WeekLayout.rangeFor(const <CalendarEntry>[]);
      expect(range.startHour, 8);
      expect(range.endHour, 18);
      expect(range.hourCount, 10);
    });

    test('spans the entries that exist', () {
      final GridRange range = WeekLayout.rangeFor(<CalendarEntry>[
        _e('a', fromH: 10, toH: 12),
        _e('b', fromH: 14, toH: 16),
      ]);
      expect(range.startHour, 10);
      expect(range.endHour, 16);
    });

    test('an entry ending on the hour does not add an empty row', () {
      final GridRange range = WeekLayout.rangeFor(<CalendarEntry>[
        _e('a', fromH: 9, toH: 13),
      ]);
      expect(range.endHour, 13);
    });

    test('an entry ending mid-hour gets its row', () {
      final GridRange range = WeekLayout.rangeFor(<CalendarEntry>[
        _e('a', fromH: 9, toH: 13, toM: 30),
      ]);
      expect(range.endHour, 14);
    });

    test('never degenerates into a single stripe', () {
      // One 15-minute entry must not produce a grid one row tall.
      final GridRange range = WeekLayout.rangeFor(<CalendarEntry>[
        _e('a', fromH: 10, toH: 10, toM: 15),
      ]);
      expect(range.hourCount, greaterThanOrEqualTo(4));
    });

    test('all-day entries do not stretch the grid', () {
      final GridRange range = WeekLayout.rangeFor(<CalendarEntry>[
        _e('deadline', fromH: 0, toH: 23, allDay: true),
        _e('lecture', fromH: 10, toH: 12),
      ]);
      expect(range.startHour, 10);
      expect(range.endHour, greaterThanOrEqualTo(12));
    });
  });

  group('placing a day', () {
    test('a lone entry gets the full width', () {
      final PlacedEntry only = WeekLayout.placeDay(<CalendarEntry>[
        _e('a', fromH: 10, toH: 12),
      ]).single;
      expect(only.lane, 0);
      expect(only.laneCount, 1);
      expect(only.startMinute, 600);
      expect(only.endMinute, 720);
    });

    test('two overlapping entries share the width', () {
      final Map<String, PlacedEntry> placed = _byId(
        WeekLayout.placeDay(<CalendarEntry>[
          _e('a', fromH: 10, toH: 12),
          _e('b', fromH: 11, toH: 13),
        ]),
      );
      expect(placed['a']!.laneCount, 2);
      expect(placed['b']!.laneCount, 2);
      expect(placed['a']!.lane, isNot(placed['b']!.lane));
    });

    test('entries that only touch do not overlap', () {
      // 10–12 and 12–14 are back to back, not simultaneous.
      final Map<String, PlacedEntry> placed = _byId(
        WeekLayout.placeDay(<CalendarEntry>[
          _e('a', fromH: 10, toH: 12),
          _e('b', fromH: 12, toH: 14),
        ]),
      );
      expect(placed['a']!.laneCount, 1);
      expect(placed['b']!.laneCount, 1);
    });

    test('a chain of overlaps is laid out as one group', () {
      // A overlaps B, B overlaps C, A and C do not touch. B cannot be two
      // widths at once, so all three belong to the same group and must agree
      // on how wide that group is — two lanes here, because A and C can share
      // one. What matters is the agreement, not the number.
      final Map<String, PlacedEntry> placed = _byId(
        WeekLayout.placeDay(<CalendarEntry>[
          _e('a', fromH: 10, toH: 12),
          _e('b', fromH: 11, toH: 14),
          _e('c', fromH: 13, toH: 15),
        ]),
      );
      final Set<int> widths = <int>{
        placed['a']!.laneCount,
        placed['b']!.laneCount,
        placed['c']!.laneCount,
      };
      expect(widths, hasLength(1), reason: 'one group, one width');
      expect(widths.single, 2);
      // B is simultaneous with both, so it cannot share their lane.
      expect(placed['b']!.lane, isNot(placed['a']!.lane));
      expect(placed['b']!.lane, isNot(placed['c']!.lane));
    });

    test('a lane is reused once its entry has ended', () {
      final Map<String, PlacedEntry> placed = _byId(
        WeekLayout.placeDay(<CalendarEntry>[
          _e('morning', fromH: 8, toH: 10),
          _e('parallel', fromH: 9, toH: 16),
          _e('afternoon', fromH: 11, toH: 13),
        ]),
      );
      // "afternoon" can take the lane "morning" vacated.
      expect(placed['afternoon']!.lane, placed['morning']!.lane);
    });

    test('a very short entry is still drawn tall enough to hit', () {
      final PlacedEntry only = WeekLayout.placeDay(<CalendarEntry>[
        _e('quick', fromH: 10, toH: 10, toM: 5),
      ]).single;
      expect(
        only.durationMinutes,
        greaterThanOrEqualTo(WeekLayout.minimumVisibleMinutes),
      );
    });

    test('all-day entries are not placed on the grid', () {
      // They belong in the header band, not in a time slot.
      expect(
        WeekLayout.placeDay(<CalendarEntry>[
          _e('deadline', fromH: 0, toH: 23, allDay: true),
        ]),
        isEmpty,
      );
    });

    test('the order is stable for identical starts', () {
      List<String> ids() => WeekLayout.placeDay(<CalendarEntry>[
        _e('b', fromH: 10, toH: 11),
        _e('a', fromH: 10, toH: 11),
      ]).map((PlacedEntry p) => p.entry.id).toList();
      expect(ids(), ids());
    });

    test('an empty day places nothing', () {
      expect(WeekLayout.placeDay(const <CalendarEntry>[]), isEmpty);
    });
  });
}
