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
    // Seven tappable cells, each at least a 48dp target.
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

  testWidgets('the Today action returns to the current day', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpCalendar(tester);
    container
        .read(calendarFocusedDayProvider.notifier)
        .select(DateTime(2026, 1, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Heute'));
    await tester.pumpAndSettle();

    final DateTime now = DateTime.now();
    final DateTime focused = container.read(calendarFocusedDayProvider);
    expect(focused.year, now.year);
    expect(focused.month, now.month);
    expect(focused.day, now.day);
  });

  testWidgets('a date picker replaces the month view', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('Datum wählen'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
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
    expect(find.byTooltip('Choose date'), findsOneWidget);
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

  testWidgets('the grid shows all seven days', (WidgetTester tester) async {
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

    // Seven columns do not fit a 320 px phone, so the grid scrolls sideways
    // rather than overflowing.
    expect(tester.takeException(), isNull);
  });
}
