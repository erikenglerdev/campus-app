// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_router.dart';
import 'package:campus_koethen/app/app_routes.dart';
import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/today/presentation/today_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_adapter.dart';

/// Pumps the real router and shell on a phone-sized surface.
Future<void> pumpApp(
  WidgetTester tester, {
  KeyValueStore? store,
  Locale locale = AppLocales.german,
  String initialLocation = AppRoutes.today,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
      contentCacheProvider.overrideWithValue(
        SafeContentCache(MemoryContentCache()),
      ),
      // No test ever reaches the network: every request answers immediately
      // with an empty envelope, so the tree settles and no timer outlives it.
      apiClientProvider.overrideWithValue(_emptyApi()),
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
        routerConfig: createAppRouter(initialLocation: initialLocation),
      ),
    ),
  );
  // Some screens keep a progress indicator running while their service is not
  // configured, so settling is not always possible — a few frames are enough
  // to lay the shell out.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ApiClient _emptyApi() => fakeApiClient(
  FakeHttpAdapter(
    (RequestOptions options) => FakeHttpResponse(envelope(<Object>[])),
  ),
);

/// Finds text inside the navigation bar only — several section names also
/// appear as headings on the screen behind it.
Finder inBar(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('the app opens on Today', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('the default bar shows Today, three middles and More', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.destinations, hasLength(5));
    expect(inBar('Heute'), findsOneWidget);
    expect(inBar('Mehr'), findsOneWidget);
    expect(inBar('Kalender'), findsOneWidget);
    expect(inBar('Mensa'), findsOneWidget);
    expect(inBar('News'), findsOneWidget);
  });

  testWidgets('a stored configuration changes the middle three', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.navigationMiddle, <String>[
      AppSection.mail.storageValue,
      AppSection.todos.storageValue,
      AppSection.campusMap.storageValue,
    ]);

    await pumpApp(tester, store: store);

    expect(inBar('Heute'), findsOneWidget);
    expect(inBar('Mehr'), findsOneWidget);
    expect(inBar('Aufgaben'), findsOneWidget);
    expect(inBar('Lageplan'), findsOneWidget);
    // …and the defaults are gone.
    expect(inBar('Kalender'), findsNothing);
    expect(inBar('Mensa'), findsNothing);
  });

  testWidgets('a corrupted configuration still yields a usable bar', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.navigationMiddle, <String>[
      'removed-section',
      AppSection.more.storageValue,
      AppSection.today.storageValue,
    ]);

    await pumpApp(tester, store: store);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.destinations, hasLength(5));
    expect(inBar('Heute'), findsOneWidget);
    expect(inBar('Mehr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a tab switches section', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(inBar('Mehr'));
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsNothing);
    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.selectedIndex, 4);
  });

  testWidgets('a section reached outside the bar highlights More', (
    WidgetTester tester,
  ) async {
    // Grades is not in the default bar. Opening it must not leave the bar with
    // nothing selected — More is where it was reached from.
    await pumpApp(tester, initialLocation: AppRoutes.grades, settle: false);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.selectedIndex, 4);
  });

  testWidgets('the bar is localised', (WidgetTester tester) async {
    await pumpApp(tester, locale: AppLocales.english);
    expect(inBar('Today'), findsOneWidget);
    expect(inBar('More'), findsOneWidget);
    expect(inBar('Heute'), findsNothing);
  });

  testWidgets('every tab keeps a 48dp touch target', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final Size bar = tester.getSize(find.byType(NavigationBar));
    expect(bar.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the bar survives a narrow phone and large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        contentCacheProvider.overrideWithValue(
          SafeContentCache(MemoryContentCache()),
        ),
        apiClientProvider.overrideWithValue(_emptyApi()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: AppLocales.german,
          supportedLocales: AppLocales.supported,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child ?? const SizedBox.shrink(),
          ),
          routerConfig: createAppRouter(initialLocation: AppRoutes.today),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
