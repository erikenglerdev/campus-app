// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/app/app_sections.dart';
import 'package:campus_koethen/app/navigation_config.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/accent_palette.dart';
import 'package:campus_koethen/core/theme/app_density.dart';
import 'package:campus_koethen/features/today/domain/dashboard_card.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('personalisation defaults', () {
    test('a fresh install starts on the product defaults', () {
      final AppSettings settings = _container(
        InMemoryKeyValueStore(),
      ).read(settingsProvider);

      expect(settings.accentPalette, AccentPalette.campusViolet);
      expect(settings.displayDensity, DisplayDensity.comfortable);
      expect(settings.reducedMotion, isFalse);
      expect(settings.navigation, NavigationConfig.defaults);
      expect(settings.dashboard, DashboardConfig.defaults);
      expect(settings.defaultBuildingKey, isNull);
      expect(
        settings.onboardingCompleted,
        isFalse,
        reason: 'the first launch must be able to tell it is the first',
      );
    });

    test(
      'a corrupted store degrades to defaults instead of throwing',
      () async {
        final InMemoryKeyValueStore store = InMemoryKeyValueStore();
        await store.setString(PreferenceKeys.accentPalette, 'neon-pink');
        await store.setString(PreferenceKeys.displayDensity, 'enormous');
        await store.setStringList(PreferenceKeys.navigationMiddle, <String>[
          'nope',
        ]);
        await store.setStringList(PreferenceKeys.dashboardCardOrder, <String>[
          'gone',
        ]);

        final AppSettings settings = _container(store).read(settingsProvider);
        expect(settings.accentPalette, AccentPalette.fallback);
        expect(settings.displayDensity, DisplayDensity.fallback);
        expect(settings.navigation.isValid, isTrue);
        expect(settings.dashboard.order.length, DashboardCard.values.length);
      },
    );
  });

  group('writing settings', () {
    test('each axis persists and reads back', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = _container(store);
      final SettingsController controller = container.read(
        settingsProvider.notifier,
      );

      await controller.setAccentPalette(AccentPalette.deepTeal);
      await controller.setDisplayDensity(DisplayDensity.compact);
      await controller.setReducedMotion(true);
      await controller.setDefaultBuilding('demo-north');
      await controller.setOnboardingCompleted(true);
      await controller.setNavigationMiddle(<AppSection>[
        AppSection.mail,
        AppSection.todos,
        AppSection.campusMap,
      ]);

      // The live state is updated…
      final AppSettings live = container.read(settingsProvider);
      expect(live.accentPalette, AccentPalette.deepTeal);
      expect(live.displayDensity, DisplayDensity.compact);
      expect(live.reducedMotion, isTrue);
      expect(live.defaultBuildingKey, 'demo-north');
      expect(live.onboardingCompleted, isTrue);
      expect(live.navigation.middle, <AppSection>[
        AppSection.mail,
        AppSection.todos,
        AppSection.campusMap,
      ]);

      // …and so is the store, so a restart keeps the choice.
      final AppSettings reloaded = _container(store).read(settingsProvider);
      expect(reloaded.accentPalette, AccentPalette.deepTeal);
      expect(reloaded.displayDensity, DisplayDensity.compact);
      expect(reloaded.reducedMotion, isTrue);
      expect(reloaded.defaultBuildingKey, 'demo-north');
      expect(reloaded.onboardingCompleted, isTrue);
      expect(reloaded.navigation, live.navigation);
    });

    test(
      'an invalid navigation wish is repaired before it is stored',
      () async {
        final InMemoryKeyValueStore store = InMemoryKeyValueStore();
        final SettingsController controller = _container(
          store,
        ).read(settingsProvider.notifier);

        // Fixed entries and a duplicate — none of this may reach storage.
        await controller.setNavigationMiddle(<AppSection>[
          AppSection.more,
          AppSection.news,
          AppSection.news,
          AppSection.today,
        ]);

        final List<String>? stored = store.getStringList(
          PreferenceKeys.navigationMiddle,
        );
        expect(stored, hasLength(3));
        expect(stored, isNot(contains(AppSection.more.storageValue)));
        expect(stored, isNot(contains(AppSection.today.storageValue)));
        expect(stored!.toSet().length, 3);
      },
    );

    test('dashboard order and hidden cards persist together', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final SettingsController controller = _container(
        store,
      ).read(settingsProvider.notifier);

      await controller.setDashboard(
        DashboardConfig.defaults
            .reordered(DashboardCard.quickActions, 0)
            .withVisibility(DashboardCard.news, visible: false),
      );

      final AppSettings reloaded = _container(store).read(settingsProvider);
      expect(reloaded.dashboard.order.first, DashboardCard.quickActions);
      expect(reloaded.dashboard.isVisible(DashboardCard.news), isFalse);
      expect(reloaded.dashboard.visible, isNot(contains(DashboardCard.news)));
    });

    test('clearing the default building removes the key', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final SettingsController controller = _container(
        store,
      ).read(settingsProvider.notifier);

      await controller.setDefaultBuilding('demo-north');
      await controller.setDefaultBuilding(null);

      expect(store.getString(PreferenceKeys.defaultBuilding), isNull);
    });
  });

  group('local reset', () {
    test('returns every preference to its default', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = _container(store);
      final SettingsController controller = container.read(
        settingsProvider.notifier,
      );

      await controller.setThemeMode(ThemeMode.dark);
      await controller.setAccentPalette(AccentPalette.warmAmber);
      await controller.setDisplayDensity(DisplayDensity.compact);
      await controller.setReducedMotion(true);
      await controller.setPreferredCanteen('mensa-koethen');
      await controller.setDefaultBuilding('demo-north');
      await controller.setOnboardingCompleted(true);

      await controller.resetLocalPreferences();

      final AppSettings after = container.read(settingsProvider);
      expect(after.themeMode, ThemeMode.system);
      expect(after.accentPalette, AccentPalette.fallback);
      expect(after.displayDensity, DisplayDensity.fallback);
      expect(after.reducedMotion, isFalse);
      expect(after.preferredCanteenSlug, isNull);
      expect(after.defaultBuildingKey, isNull);
      expect(
        after.onboardingCompleted,
        isFalse,
        reason: 'a reset app must offer its onboarding again',
      );

      // And the store is genuinely empty, not just the in-memory state.
      final AppSettings reloaded = _container(store).read(settingsProvider);
      expect(reloaded.accentPalette, AccentPalette.fallback);
      expect(reloaded.onboardingCompleted, isFalse);
    });

    test('does not touch keys owned by the secure personal services', () async {
      // The reset is scoped to presentation and preferences. Credentials and
      // encrypted caches belong to "remove account" inside each service — a
      // settings reset must never half-delete a mail account.
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await store.setString('mail.account.host.v1', 'mail.example.org');
      await store.setInt('grades.lastSync.v1', 1234);

      await _container(
        store,
      ).read(settingsProvider.notifier).resetLocalPreferences();

      expect(store.getString('mail.account.host.v1'), 'mail.example.org');
      expect(store.getInt('grades.lastSync.v1'), 1234);
    });
  });
}
