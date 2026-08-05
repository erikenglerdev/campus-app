// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/presentation/calendar_screen.dart';
import 'package:campus_koethen/features/calendar/presentation/week_grid_view.dart';
import 'package:campus_koethen/features/calendar/presentation/week_strip.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

ApiClient _emptyApi() => fakeApiClient(
  FakeHttpAdapter((RequestOptions _) => FakeHttpResponse(envelope(<Object>[]))),
);

Future<ProviderContainer> pumpCalendar(
  WidgetTester tester, {
  KeyValueStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = await pumpScreen(
    tester,
    const CalendarScreen(),
    locale: locale,
    keyValueStore: store,
    overrides: <Override>[apiClientProvider.overrideWithValue(_emptyApi())],
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('starts with the views and the sources, without an app bar', (
    WidgetTester tester,
  ) async {
    // A title saying "Kalender" above a calendar, next to icons whose meaning
    // had to be guessed, was a row of a phone's height spent on nothing.
    await pumpCalendar(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Kalender'), findsNothing);
    expect(find.text('Tag'), findsOneWidget);
    expect(find.text('Woche'), findsOneWidget);
    expect(find.text('Liste'), findsOneWidget);
  });

  testWidgets('puts the sources above the view selection, on one line', (
    WidgetTester tester,
  ) async {
    // Which calendars you are looking at comes first; how you look at them
    // second. The three sources are one row, not a block of stacked buttons.
    await pumpCalendar(tester);

    final double sources = tester.getTopLeft(find.text('Stundenplan')).dy;
    final double views = tester
        .getTopLeft(find.byType(SegmentedButton<CalendarViewMode>))
        .dy;

    expect(sources, lessThan(views));
    expect(tester.getTopLeft(find.text('Moodle')).dy, closeTo(sources, 0.5));
    expect(tester.getTopLeft(find.text('Events')).dy, closeTo(sources, 0.5));
  });

  testWidgets('opens on the day agenda, not on a month grid', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpCalendar(tester);

    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
    expect(
      find.byType(WeekStrip),
      findsOneWidget,
      reason: 'the week strip replaces the month grid as the day picker',
    );
  });

  testWidgets('the week strip offers seven days', (WidgetTester tester) async {
    await pumpCalendar(tester);

    final WeekStrip strip = tester.widget<WeekStrip>(find.byType(WeekStrip));
    expect(strip.entryCounts, isNotNull);
    // Seven tappable cells, each at least a 48dp target — the day picker keeps
    // the weekend reachable even when the week VIEW is Monday to Friday.
    final Iterable<Semantics> cells = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(WeekStrip),
            matching: find.byType(Semantics),
          ),
        )
        .where((Semantics s) => s.properties.button ?? false);
    expect(cells.length, 7);
  });

  testWidgets('tapping a day in the strip moves the agenda', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpCalendar(tester);
    final DateTime before = container.read(calendarFocusedDayProvider);

    final WeekStrip strip = tester.widget<WeekStrip>(find.byType(WeekStrip));
    // Pick a day that is definitely not the current one.
    final DateTime target = before.add(
      Duration(days: before.weekday == DateTime.monday ? 2 : -1),
    );
    strip.onSelect(target);
    await tester.pumpAndSettle();

    final DateTime after = container.read(calendarFocusedDayProvider);
    expect(after.day, target.day);
    expect(after, isNot(before));
  });

  group('moving through the weeks', () {
    testWidgets('swiping the strip moves one week and keeps the weekday', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpCalendar(tester);
      final DateTime before = container.read(calendarFocusedDayProvider);

      await tester.fling(find.byType(WeekStrip), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      final DateTime after = container.read(calendarFocusedDayProvider);
      expect(after.difference(before).inDays, 7);
      expect(after.weekday, before.weekday);
    });

    testWidgets('and back the other way, arbitrarily far', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpCalendar(tester);
      final DateTime before = container.read(calendarFocusedDayProvider);

      for (int i = 0; i < 6; i++) {
        await tester.fling(find.byType(WeekStrip), const Offset(200, 0), 1000);
        await tester.pumpAndSettle();
      }

      final DateTime after = container.read(calendarFocusedDayProvider);
      expect(after.difference(before).inDays, -42);
      expect(after.weekday, before.weekday);
    });

    testWidgets('the day content still swipes a day at a time', (
      WidgetTester tester,
    ) async {
      // Two gestures, two areas: neither may swallow the other.
      final ProviderContainer container = await pumpCalendar(tester);
      final DateTime before = container.read(calendarFocusedDayProvider);

      await tester.fling(
        find.text('Keine Einträge an diesem Tag.'),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        container.read(calendarFocusedDayProvider).difference(before).inDays,
        1,
      );
    });

    testWidgets('Today comes back from wherever the swiping ended up', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpCalendar(tester);
      container
          .read(calendarFocusedDayProvider.notifier)
          .select(DateTime(2026, 1, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();

      final DateTime now = DateTime.now();
      final DateTime focused = container.read(calendarFocusedDayProvider);
      expect(focused.year, now.year);
      expect(focused.month, now.month);
      expect(focused.day, now.day);
    });
  });

  group('the source controls', () {
    testWidgets('name all three sources and their state', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester);

      expect(find.text('Stundenplan'), findsOneWidget);
      expect(find.text('Moodle'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      // State in words, never in a colour alone.
      expect(find.text('Sichtbar'), findsNWidgets(2));
      expect(find.text('Nicht verbunden'), findsOneWidget);
    });

    testWidgets('the timetable control opens its sheet', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.text('Stundenplan'));
      await tester.pumpAndSettle();

      expect(find.text('Im Kalender anzeigen'), findsOneWidget);
      expect(find.text('Noch kein Kurs gewählt'), findsOneWidget);
      // Twice: the sheet's button, and the hint on the screen behind it.
      expect(find.text('Kurs wählen'), findsNWidgets(2));
    });

    testWidgets('hiding a source from its sheet is remembered', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = await pumpCalendar(
        tester,
        store: store,
      );

      await tester.tap(find.text('Stundenplan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Im Kalender anzeigen'));
      await tester.pumpAndSettle();

      expect(
        container.read(calendarEnabledSourcesProvider),
        isNot(contains(CalendarSource.timetable)),
      );
      expect(
        store.getStringList(PreferenceKeys.calendarDisabledSources),
        <String>[CalendarSource.timetable.storageValue],
      );
    });

    testWidgets('the Moodle control explains itself when not connected', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.text('Moodle'));
      await tester.pumpAndSettle();

      expect(find.text('Moodle verbinden'), findsOneWidget);
      // Nothing to switch yet — the sheet offers the way in instead.
      expect(find.text('Im Kalender anzeigen'), findsNothing);
    });

    testWidgets('the events control opens the public calendars', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();

      expect(find.text('Öffentliche Kalender'), findsOneWidget);
      expect(
        find.text('Ausgewählte in Google Kalender öffnen'),
        findsOneWidget,
      );
    });
  });

  group('week view', _weekViewTests);

  group('source filters', () {
    testWidgets('every source is on for a fresh install', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpCalendar(tester);
      expect(
        container.read(calendarEnabledSourcesProvider),
        CalendarSource.values.toSet(),
      );
    });

    testWidgets('switching a source off is remembered', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = await pumpCalendar(
        tester,
        store: store,
      );

      await container
          .read(calendarEnabledSourcesProvider.notifier)
          .toggle(CalendarSource.timetable);
      await tester.pumpAndSettle();

      expect(
        container.read(calendarEnabledSourcesProvider),
        isNot(contains(CalendarSource.timetable)),
      );
      // Stored as the DISABLED set, so a source added later defaults to on.
      expect(
        store.getStringList(PreferenceKeys.calendarDisabledSources),
        <String>[CalendarSource.timetable.storageValue],
      );

      // A fresh container reading the same store keeps the choice.
      final ProviderContainer restarted = ProviderContainer(
        overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restarted.dispose);
      expect(
        restarted.read(calendarEnabledSourcesProvider),
        isNot(contains(CalendarSource.timetable)),
      );
    });

    testWidgets('an unknown stored source is ignored, not fatal', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await store.setStringList(
        PreferenceKeys.calendarDisabledSources,
        <String>[
          'a-source-that-was-removed',
          CalendarSource.moodle.storageValue,
        ],
      );

      final ProviderContainer container = await pumpCalendar(
        tester,
        store: store,
      );

      expect(container.read(calendarEnabledSourcesProvider), <CalendarSource>{
        CalendarSource.timetable,
        CalendarSource.publicCalendar,
      });
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpCalendar(tester, locale: AppLocales.english);

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Visible'), findsNWidgets(2));
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      const CalendarScreen(),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[apiClientProvider.overrideWithValue(_emptyApi())],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// The optional graphical week view.
void _weekViewTests() {
  testWidgets('the week view is offered as a third mode', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpCalendar(tester);
    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);

    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    await tester.pumpAndSettle();

    expect(find.byType(WeekGridView), findsOneWidget);
    expect(find.byType(WeekStrip), findsNothing);
  });

  testWidgets('starts on the teaching week and can take the weekend', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer container = await pumpCalendar(
      tester,
      store: store,
    );
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    await tester.pumpAndSettle();

    expect(
      tester.widget<WeekGridView>(find.byType(WeekGridView)).dayCount,
      5,
      reason: 'Monday to Friday by default',
    );

    await tester.tap(find.text('Wochenende'));
    await tester.pumpAndSettle();

    expect(tester.widget<WeekGridView>(find.byType(WeekGridView)).dayCount, 7);
    expect(store.getInt(PreferenceKeys.calendarShowWeekend), 1);
  });

  testWidgets('the grid starts on a Monday', (WidgetTester tester) async {
    final ProviderContainer container = await pumpCalendar(tester);
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    await tester.pumpAndSettle();

    final WeekGridView grid = tester.widget<WeekGridView>(
      find.byType(WeekGridView),
    );
    expect(grid.weekStart.weekday, DateTime.monday);
  });

  testWidgets('picking a day in the grid opens that day', (
    WidgetTester tester,
  ) async {
    // The week answers "how is my week shaped"; the day answers "what is on".
    final ProviderContainer container = await pumpCalendar(tester);
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    await tester.pumpAndSettle();

    final WeekGridView grid = tester.widget<WeekGridView>(
      find.byType(WeekGridView),
    );
    final DateTime target = grid.weekStart.add(const Duration(days: 3));
    grid.onSelectDay(target);
    await tester.pumpAndSettle();

    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
    expect(container.read(calendarFocusedDayProvider).day, target.day);
  });

  testWidgets('the week survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = await pumpScreen(
      tester,
      const CalendarScreen(),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[apiClientProvider.overrideWithValue(_emptyApi())],
    );
    await tester.pumpAndSettle();
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    await tester.pumpAndSettle();

    // The columns share whatever width is left rather than overflowing.
    expect(tester.takeException(), isNull);
  });
}
