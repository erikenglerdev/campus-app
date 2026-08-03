// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_router.dart';
import 'package:campus_koethen/app/app_routes.dart';
import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/today/presentation/today_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_adapter.dart';

/// Pumps the full app including the router and the bottom navigation.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Locale locale = AppLocales.german,
  KeyValueStore? store,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
      contentCacheProvider.overrideWithValue(
        SafeContentCache(MemoryContentCache()),
      ),
      // An empty envelope rather than a thrown request: these tests assert the
      // navigation bar, not offline behaviour, and a throwing adapter leaves a
      // retry timer pending once the dashboard is the first screen.
      apiClientProvider.overrideWithValue(
        fakeApiClient(
          FakeHttpAdapter(
            (RequestOptions _) => FakeHttpResponse(envelope(<Object>[])),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: createAppRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('offers five destinations in the agreed order', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(
      bar.destinations.cast<NavigationDestination>().map(
        (NavigationDestination destination) => destination.label,
      ),
      // The redesign puts the day dashboard first and keeps More last; the
      // three between them are the user's defaults until they change them.
      <String>['Heute', 'Kalender', 'Mensa', 'News', 'Mehr'],
    );
  });

  testWidgets('navigates to the calendar', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kalender'),
      ),
    );
    await tester.pumpAndSettle();

    // The calendar's explicit view toggle (month vs list) is shown.
    expect(find.text('Liste'), findsOneWidget);
  });

  testWidgets('starts on the day dashboard', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(AppRoutes.today, '/today');
    expect(find.byType(TodayScreen), findsOneWidget);
    // The calendar view toggle is not shown until the Kalender tab is opened.
    expect(find.text('Liste'), findsNothing);
  });

  testWidgets('keeps five destinations usable on a narrow device', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    for (final String label in <String>[
      'Heute',
      'Kalender',
      'Mensa',
      'News',
      'Mehr',
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: '$label is missing from the navigation bar',
      );
    }

    final Size barSize = tester.getSize(find.byType(NavigationBar));
    expect(
      barSize.height,
      greaterThanOrEqualTo(48.0),
      reason: 'the navigation bar keeps a 48dp touch target',
    );
    expect(
      barSize.width / 5,
      greaterThanOrEqualTo(48.0),
      reason: 'every one of the five destinations stays hittable',
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kalender'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Liste'), findsOneWidget);
  });

  testWidgets('renders the English navigation', (WidgetTester tester) async {
    await pumpApp(tester, locale: AppLocales.english);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
  });
}
