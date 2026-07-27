// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:ui';

import 'package:campus_koethen/core/theme/hex_color.dart';
import 'package:campus_koethen/features/calendar/application/calendar_merge.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/domain/public_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

PublicCalendar cal(String slug, String color) => PublicCalendar(
  id: 'id-$slug',
  slug: slug,
  name: 'Kalender $slug',
  colorHex: color,
  iconKey: 'calendar',
  sortOrder: 0,
  defaultSubscribed: false,
  googleOpenUrl: 'https://calendar.google.com/calendar/render?cid=x',
);

PublicCalendarEvent event(String slug, String id) => PublicCalendarEvent(
  id: id,
  calendarId: 'c-$slug',
  calendarSlug: slug,
  title: 'Öffentliche Veranstaltung',
  start: DateTime.utc(2026, 6, 10, 8),
  end: DateTime.utc(2026, 6, 10, 9),
);

void main() {
  group('parseHexColor', () {
    test('parses #RRGGBB', () {
      expect(parseHexColor('#5B3FD0'), const Color(0xFF5B3FD0));
    });
    test('parses #AARRGGBB', () {
      expect(parseHexColor('#805B3FD0'), const Color(0x805B3FD0));
    });
    test('returns null for malformed values', () {
      expect(parseHexColor('red'), isNull);
      expect(parseHexColor('#12'), isNull);
      expect(parseHexColor(null), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
    });
  });

  group('publicCalendarEventsToCalendarEntries', () {
    test('maps events, resolving colour + name from the catalogue by slug', () {
      final Map<String, PublicCalendar> bySlug = <String, PublicCalendar>{
        'a': cal('a', '#5B3FD0'),
      };
      final List<CalendarEntry> entries = publicCalendarEventsToCalendarEntries(
        <PublicCalendarEvent>[event('a', 'e1')],
        bySlug,
      );
      expect(entries, hasLength(1));
      final CalendarEntry e = entries.first;
      expect(e.source, CalendarSource.publicCalendar);
      expect(e.id, 'publicCalendar:a:e1');
      expect(e.calendarSlug, 'a');
      expect(e.sourceLabel, 'Kalender a');
      expect(e.colorArgb, const Color(0xFF5B3FD0).toARGB32());
    });

    test(
      'falls back gracefully when the calendar is unknown or the colour bad',
      () {
        final List<CalendarEntry> entries =
            publicCalendarEventsToCalendarEntries(
              <PublicCalendarEvent>[event('ghost', 'e1')],
              <String, PublicCalendar>{'ghost': cal('ghost', 'not-a-color')},
            );
        expect(entries.first.colorArgb, isNull); // bad colour → no accent
        expect(entries.first.sourceLabel, 'Kalender ghost');
      },
    );

    test('merges with other sources and stays sorted by start', () {
      final List<CalendarEntry> merged = mergeCalendarEntries(<CalendarEntry>[
        CalendarEntry(
          id: 'timetable:x',
          source: CalendarSource.timetable,
          title: 'Vorlesung',
          start: DateTime.utc(2026, 6, 10, 7),
        ),
        ...publicCalendarEventsToCalendarEntries(
          <PublicCalendarEvent>[event('a', 'e1')],
          <String, PublicCalendar>{'a': cal('a', '#5B3FD0')},
        ),
      ]);
      expect(
        merged.map((CalendarEntry e) => e.source).toList(),
        <CalendarSource>[
          CalendarSource.timetable,
          CalendarSource.publicCalendar,
        ],
      );
    });
  });
}
