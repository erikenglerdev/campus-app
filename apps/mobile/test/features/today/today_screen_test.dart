// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/today/domain/dashboard_card.dart';
import 'package:campus_koethen/features/today/presentation/today_screen.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

const CalendarData _healthy = CalendarData(
  entries: <CalendarEntry>[],
  enabledSources: <CalendarSource>{},
  timetableLoading: false,
  hasTimetableError: false,
  needsGroup: false,
  moodleConnected: false,
  hasMoodleError: false,
  publicCalendarsLoading: false,
  hasPublicCalendarError: false,
);

CalendarEntry _lecture(
  String title, {
  required DateTime start,
  required DateTime end,
  String? location,
  CalendarSource source = CalendarSource.timetable,
}) => CalendarEntry(
  id: title,
  source: source,
  title: title,
  start: start,
  end: end,
  location: location,
);

ApiClient _emptyApi() => fakeApiClient(
  FakeHttpAdapter((RequestOptions _) => FakeHttpResponse(envelope(<Object>[]))),
);

/// Pumps the dashboard with a fixed clock and a supplied agenda.
Future<void> pumpToday(
  WidgetTester tester, {
  required DateTime now,
  List<CalendarEntry> entries = const <CalendarEntry>[],
  CalendarData data = _healthy,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final DateTime day = DateTime(now.year, now.month, now.day);
  await pumpScreen(
    tester,
    TodayScreen(now: now),
    locale: locale,
    overrides: <Override>[
      apiClientProvider.overrideWithValue(_emptyApi()),
      dayAgendaProvider(
        day,
      ).overrideWithValue(DayAgenda(date: day, entries: entries, data: data)),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an ongoing lecture is announced as happening now', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime(2026, 5, 12, 10, 30);
    await pumpToday(
      tester,
      now: now,
      entries: <CalendarEntry>[
        _lecture(
          'Analysis II',
          start: DateTime(2026, 5, 12, 10),
          end: DateTime(2026, 5, 12, 12),
          location: 'B.201',
        ),
      ],
    );

    expect(find.text('Gerade jetzt'), findsOneWidget);
    expect(find.text('Analysis II'), findsOneWidget);
    expect(find.text('B.201'), findsOneWidget);
    // The source is named, not just coloured.
    expect(find.text('Stundenplan'), findsWidgets);
  });

  testWidgets('between lectures the next one is announced', (
    WidgetTester tester,
  ) async {
    await pumpToday(
      tester,
      now: DateTime(2026, 5, 12, 13),
      entries: <CalendarEntry>[
        _lecture(
          'Statistik',
          start: DateTime(2026, 5, 12, 14),
          end: DateTime(2026, 5, 12, 16),
        ),
      ],
    );

    expect(find.text('Als Nächstes'), findsOneWidget);
    expect(find.text('Statistik'), findsOneWidget);
  });

  testWidgets('an empty day says so instead of showing a blank card', (
    WidgetTester tester,
  ) async {
    await pumpToday(tester, now: DateTime(2026, 5, 12, 15));
    expect(find.text('Für heute ist nichts mehr eingetragen.'), findsOneWidget);
  });

  testWidgets('one broken source leaves the other cards standing', (
    WidgetTester tester,
  ) async {
    // The timetable is down, but a Moodle deadline still arrived.
    const CalendarData timetableDown = CalendarData(
      entries: <CalendarEntry>[],
      enabledSources: <CalendarSource>{},
      timetableLoading: false,
      hasTimetableError: true,
      needsGroup: false,
      moodleConnected: true,
      hasMoodleError: false,
      publicCalendarsLoading: false,
      hasPublicCalendarError: false,
    );

    await pumpToday(
      tester,
      now: DateTime(2026, 5, 12, 9),
      data: timetableDown,
      entries: <CalendarEntry>[
        _lecture(
          'Abgabe Übungsblatt 3',
          start: DateTime(2026, 5, 12, 23, 59),
          end: DateTime(2026, 5, 12, 23, 59),
          source: CalendarSource.moodle,
        ),
      ],
    );

    expect(find.text('Abgabe Übungsblatt 3'), findsOneWidget);
    // …and the unrelated cards are untouched.
    expect(find.text('Aufgaben'), findsOneWidget);
    expect(find.text('Schnellzugriff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late at night the dashboard announces the next day', (
    WidgetTester tester,
  ) async {
    await pumpToday(tester, now: DateTime(2026, 5, 12, 23, 15));
    expect(find.text('Vorschau auf morgen'), findsOneWidget);
  });

  testWidgets('the greeting follows the time of day', (
    WidgetTester tester,
  ) async {
    await pumpToday(tester, now: DateTime(2026, 5, 12, 6));
    expect(find.text('Guten Morgen'), findsOneWidget);
  });

  testWidgets('hidden cards disappear from the dashboard', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime(2026, 5, 12, 9);
    final DateTime day = DateTime(2026, 5, 12);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = await pumpScreen(
      tester,
      TodayScreen(now: now),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(_emptyApi()),
        dayAgendaProvider(day).overrideWithValue(
          DayAgenda(
            date: day,
            entries: const <CalendarEntry>[],
            data: _healthy,
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Schnellzugriff'), findsOneWidget);

    await container
        .read(settingsProvider.notifier)
        .setDashboard(
          DashboardConfig.defaults.withVisibility(
            DashboardCard.quickActions,
            visible: false,
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Schnellzugriff'), findsNothing);
    expect(find.text('Aufgaben'), findsOneWidget);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpToday(
      tester,
      now: DateTime(2026, 5, 12, 10, 30),
      locale: AppLocales.english,
      entries: <CalendarEntry>[
        _lecture(
          'Analysis II',
          start: DateTime(2026, 5, 12, 10),
          end: DateTime(2026, 5, 12, 12),
        ),
      ],
    );
    expect(find.text('Right now'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('survives a small phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final DateTime day = DateTime(2026, 5, 12);
    await pumpScreen(
      tester,
      TodayScreen(now: DateTime(2026, 5, 12, 10)),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(_emptyApi()),
        dayAgendaProvider(day).overrideWithValue(
          DayAgenda(
            date: day,
            entries: <CalendarEntry>[
              _lecture(
                'Ein sehr langer Veranstaltungstitel für den Umbruchtest',
                start: DateTime(2026, 5, 12, 10),
                end: DateTime(2026, 5, 12, 12),
                location: 'Demogebäude Nord, Raum B.201',
              ),
            ],
            data: _healthy,
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
