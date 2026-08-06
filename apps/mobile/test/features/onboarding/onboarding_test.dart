// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_router.dart';
import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/onboarding/presentation/onboarding_screen.dart';
import 'package:campus_koethen/features/news/presentation/news_list_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

ApiClient _emptyApi() => fakeApiClient(
  FakeHttpAdapter((RequestOptions _) => FakeHttpResponse(envelope(<Object>[]))),
);

/// Pumps the real app — router, redirect and all — on a phone-sized surface.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  KeyValueStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
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
        routerConfig: container.read(appRouterProvider),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a first launch lands in the setup, not on the dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(NewsListScreen), findsNothing);
    expect(find.text('Willkommen'), findsOneWidget);
  });

  testWidgets('the welcome step carries the independence notice', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    // A project rule, not a footnote: the app must never look official.
    expect(find.textContaining('unabhängig'), findsOneWidget);
  });

  testWidgets('a completed setup goes straight to the dashboard', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setInt(PreferenceKeys.onboardingCompleted, 1);

    await pumpApp(tester, store: store);

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(NewsListScreen), findsOneWidget);
  });

  testWidgets('skipping everything finishes the setup', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer container = await pumpApp(tester, store: store);

    await tester.tap(find.text('Alles überspringen'));
    await tester.pumpAndSettle();

    // Skipping counts as answering — the app must not ask again unprompted.
    expect(container.read(settingsProvider).onboardingCompleted, isTrue);
    expect(store.getInt(PreferenceKeys.onboardingCompleted), 1);
    expect(find.byType(NewsListScreen), findsOneWidget);
  });

  testWidgets('individual steps can be skipped forward and back', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Schritt 1 von 3'), findsOneWidget);

    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 3'), findsOneWidget);
    expect(find.text('Dein Campus'), findsOneWidget);

    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 1 von 3'), findsOneWidget);
  });

  testWidgets('asks only for what the app actually needs', (
    WidgetTester tester,
  ) async {
    // Accent colour and the navigation bar are preferences, not decisions the
    // app needs before it is usable. They live in the settings.
    await pumpApp(tester);

    for (int i = 0; i < 2; i++) {
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Aussehen'), findsNothing);
    expect(find.text('Navigation'), findsNothing);
  });

  testWidgets('a choice made during setup is kept', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer container = await pumpApp(tester, store: store);

    // Step 2 is the campus step. What is asserted here is that a choice made
    // during setup is persisted — the controller is the thing under test, not
    // whether a bundled asset happened to load within this frame budget.
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Dein Campus'), findsOneWidget);

    await container
        .read(settingsProvider.notifier)
        .setPreferredCanteen('koethen-fasanerieallee');
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).preferredCanteenSlug,
      'koethen-fasanerieallee',
    );
    expect(
      store.getString(PreferenceKeys.preferredCanteen),
      'koethen-fasanerieallee',
    );
  });

  testWidgets('choosing content does not throw the user back to step one', (
    WidgetTester tester,
  ) async {
    // The global redirect sends every route back to the setup while it is
    // unfinished. A step that navigated away was therefore bounced straight
    // back — and rebuilt from the start, losing the reader's place.
    await pumpApp(tester);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Schritt 3 von 3'),
      findsOneWidget,
      reason: 'the content step',
    );
    // The pickers are here, in the step — not behind a route that the
    // redirect would bounce straight back to step one.
    expect(find.text('News-Kanäle wählen'), findsOneWidget);
    expect(find.text('Öffentliche Kalender wählen'), findsOneWidget);
    expect(find.text('Schritt 1 von 3'), findsNothing);
  });

  testWidgets('an unavailable source is stated instead of blocking', (
    WidgetTester tester,
  ) async {
    // The fake API answers every request with an empty list, so there are no
    // canteens to choose. The step must say so and stay passable.
    await pumpApp(tester);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Dein Campus'), findsOneWidget);
    expect(find.text('Es sind noch keine Mensen hinterlegt.'), findsOneWidget);
    // …and moving on still works.
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 3 von 3'), findsOneWidget);
  });

  testWidgets('the last step finishes and opens the dashboard', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);

    for (int i = 0; i < 2; i++) {
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Schritt 3 von 3'), findsOneWidget);

    await tester.tap(find.text('Los geht’s'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).onboardingCompleted, isTrue);
    expect(find.byType(NewsListScreen), findsOneWidget);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpApp(tester, locale: AppLocales.english);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Skip all'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('survives a small phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2000);
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
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
