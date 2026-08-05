// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/calendar/presentation/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// A Wednesday, so a swipe can be seen to keep the weekday.
final DateTime _wednesday = DateTime(2026, 5, 13);

Future<List<int>> _pumpStrip(
  WidgetTester tester, {
  DateTime? selected,
  DateTime? today,
  Locale locale = AppLocales.german,
  TextScaler textScaler = TextScaler.noScaling,
  List<DateTime>? selections,
}) async {
  final List<int> shifts = <int>[];

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    Scaffold(
      body: WeekStrip(
        selected: selected ?? _wednesday,
        today: today ?? _wednesday,
        entryCounts: const <DateTime, int>{},
        onSelect: (DateTime day) => selections?.add(day),
        onShiftWeeks: shifts.add,
        onToday: () {},
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
  return shifts;
}

void main() {
  group('swiping the strip', () {
    testWidgets('a swipe to the left moves one week forward', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[1]);
    });

    testWidgets('a swipe to the right moves one week back', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[-1]);
    });

    testWidgets('exactly one week per swipe, however far the finger goes', (
      WidgetTester tester,
    ) async {
      // A calendar that jumped three weeks because the flick was quick would
      // be impossible to aim.
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(-360, 0), 4000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[1]);
    });

    testWidgets('tapping a day still selects it', (WidgetTester tester) async {
      // The swipe must not swallow the taps the strip exists for.
      final List<DateTime> selections = <DateTime>[];
      final List<int> shifts = await _pumpStrip(tester, selections: selections);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(selections.single.day, 15);
      expect(shifts, isEmpty);
    });
  });

  group('finding your way back', () {
    testWidgets('names the month, which the day numbers alone do not', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(tester);

      expect(find.text('Mai 2026'), findsOneWidget);
    });

    testWidgets('offers Today once the strip has moved away from it', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(
        tester,
        selected: DateTime(2026, 7, 1),
        today: _wednesday,
      );

      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('and does not offer it in the current week', (
      WidgetTester tester,
    ) async {
      // Nothing to go back to, so the control would only be noise.
      await _pumpStrip(tester, selected: _wednesday, today: _wednesday);

      expect(find.text('Heute'), findsNothing);
    });
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await _pumpStrip(
      tester,
      selected: DateTime(2026, 7, 1),
      today: _wednesday,
      locale: AppLocales.english,
    );

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      Scaffold(
        body: WeekStrip(
          selected: DateTime(2026, 7, 1),
          today: _wednesday,
          entryCounts: const <DateTime, int>{},
          onSelect: (DateTime _) {},
          onShiftWeeks: (int _) {},
          onToday: () {},
        ),
      ),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
