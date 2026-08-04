// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/more/presentation/more_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

Future<AppLocalizations> pumpMore(
  WidgetTester tester, {
  List<AppSection>? bottomBar,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final InMemoryKeyValueStore store = InMemoryKeyValueStore();
  if (bottomBar != null) {
    await store.setStringList(
      PreferenceKeys.navigationMiddle,
      bottomBar.map((AppSection s) => s.storageValue).toList(),
    );
  }

  await pumpScreen(
    tester,
    const MoreScreen(),
    locale: locale,
    keyValueStore: store,
  );
  await tester.pumpAndSettle();

  return await AppLocalizations.delegate.load(locale);
}

void main() {
  testWidgets('every area that is not in the bottom bar is listed', (
    WidgetTester tester,
  ) async {
    // "More" is the app's promise that no area can become unreachable, whatever
    // the user puts in the three configurable slots. That only holds if the
    // list is DERIVED from the section catalogue — a hand-written list silently
    // drops whatever nobody remembered to add.
    final AppLocalizations l10n = await pumpMore(tester);

    for (final AppSection section in AppSection.configurable) {
      if (NavigationConfigForTest.defaultBar.contains(section)) continue;
      expect(
        find.text(section.label(l10n)),
        findsOneWidget,
        reason: '${section.storageValue} is reachable from nowhere',
      );
    }
  });

  testWidgets('contacts is reachable', (WidgetTester tester) async {
    // The regression that motivated this test: contacts is a section with a
    // route, sits in no default tab, and was missing from the hand-written
    // list — so the only way in was the dashboard shortcut.
    final AppLocalizations l10n = await pumpMore(tester);
    expect(find.text(AppSection.contacts.label(l10n)), findsOneWidget);
  });

  testWidgets('areas pushed out of the bottom bar show up here', (
    WidgetTester tester,
  ) async {
    // A user who fills the bar with Moodle, tasks and the campus map must not
    // lose the calendar, the canteen and the news.
    final AppLocalizations l10n = await pumpMore(
      tester,
      bottomBar: <AppSection>[
        AppSection.moodle,
        AppSection.todos,
        AppSection.campusMap,
      ],
    );

    for (final AppSection section in <AppSection>[
      AppSection.calendar,
      AppSection.canteen,
      AppSection.news,
    ]) {
      expect(find.text(section.label(l10n)), findsOneWidget);
    }
  });

  testWidgets('what is already in the bottom bar is not repeated', (
    WidgetTester tester,
  ) async {
    final AppLocalizations l10n = await pumpMore(tester);
    for (final AppSection section in <AppSection>[
      AppSection.calendar,
      AppSection.canteen,
      AppSection.news,
    ]) {
      expect(find.text(section.label(l10n)), findsNothing);
    }
  });

  testWidgets('settings are always offered', (WidgetTester tester) async {
    // Settings is not a section and has no tab, so it can never be crowded out.
    final AppLocalizations l10n = await pumpMore(
      tester,
      bottomBar: <AppSection>[
        AppSection.moodle,
        AppSection.todos,
        AppSection.campusMap,
      ],
    );
    expect(find.text(l10n.moreSettings), findsOneWidget);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    final AppLocalizations l10n = await pumpMore(
      tester,
      locale: AppLocales.english,
    );
    expect(find.text(l10n.moreSettings), findsOneWidget);
    expect(find.text(AppSection.contacts.label(l10n)), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      const MoreScreen(),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// The bar a fresh install shows, spelled out so the expectations above read
/// as statements rather than as a repetition of production code.
abstract final class NavigationConfigForTest {
  static const List<AppSection> defaultBar = <AppSection>[
    AppSection.calendar,
    AppSection.canteen,
    AppSection.news,
  ];
}
