// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_sections.dart';
import '../../app/navigation_config.dart';
import '../../features/today/domain/dashboard_card.dart';
import '../locale/locale_mode.dart';
import '../theme/accent_palette.dart';
import '../theme/app_density.dart';
import 'key_value_store.dart';
import 'preference_keys.dart';

/// All locally persisted user settings that are plain scalars.
class AppSettings {
  const AppSettings({
    this.localeMode = LocaleMode.system,
    this.themeMode = ThemeMode.system,
    this.accentPalette = AccentPalette.fallback,
    this.displayDensity = DisplayDensity.fallback,
    this.reducedMotion = false,
    this.navigation = NavigationConfig.defaults,
    this.dashboard = DashboardConfig.defaults,
    this.preferredCanteenSlug,
    this.timetableGroupId,
    this.defaultBuildingKey,
    this.onboardingCompleted = false,
    this.mailDownloadAttachments = false,
  });

  final LocaleMode localeMode;
  final ThemeMode themeMode;

  /// The chosen accent palette. Never a free colour — see [AccentPalette].
  final AccentPalette accentPalette;

  final DisplayDensity displayDensity;

  /// The **local** reduced-motion wish. The operating system's own setting is
  /// honoured separately, so this being false does not mean "animate".
  final bool reducedMotion;

  final NavigationConfig navigation;
  final DashboardConfig dashboard;

  /// Slug of the canteen the user prefers, or `null` for "not chosen yet".
  final String? preferredCanteenSlug;

  /// **Campus** UUID of the chosen timetable group, or `null` for "not chosen
  /// yet". The app never stores an upstream identifier.
  final String? timetableGroupId;

  /// buildingKey the campus map opens on, or `null` for "not chosen yet".
  final String? defaultBuildingKey;

  /// Whether the first-run onboarding has been completed **or skipped**.
  /// Skipping counts: the user answered the question by declining it.
  final bool onboardingCompleted;

  /// When true, the mail sync downloads attachment bytes too, so attachments
  /// are available offline. Off by default to keep the cache small.
  final bool mailDownloadAttachments;

  AppSettings copyWith({
    LocaleMode? localeMode,
    ThemeMode? themeMode,
    AccentPalette? accentPalette,
    DisplayDensity? displayDensity,
    bool? reducedMotion,
    NavigationConfig? navigation,
    DashboardConfig? dashboard,
    String? preferredCanteenSlug,
    bool clearPreferredCanteen = false,
    String? timetableGroupId,
    bool clearTimetableGroup = false,
    String? defaultBuildingKey,
    bool clearDefaultBuilding = false,
    bool? onboardingCompleted,
    bool? mailDownloadAttachments,
  }) {
    return AppSettings(
      localeMode: localeMode ?? this.localeMode,
      themeMode: themeMode ?? this.themeMode,
      accentPalette: accentPalette ?? this.accentPalette,
      displayDensity: displayDensity ?? this.displayDensity,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      navigation: navigation ?? this.navigation,
      dashboard: dashboard ?? this.dashboard,
      defaultBuildingKey: clearDefaultBuilding
          ? null
          : (defaultBuildingKey ?? this.defaultBuildingKey),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      preferredCanteenSlug: clearPreferredCanteen
          ? null
          : (preferredCanteenSlug ?? this.preferredCanteenSlug),
      timetableGroupId: clearTimetableGroup
          ? null
          : (timetableGroupId ?? this.timetableGroupId),
      mailDownloadAttachments:
          mailDownloadAttachments ?? this.mailDownloadAttachments,
    );
  }
}

/// The key/value store used for scalar settings.
///
/// Overridden in `main()` with the real `shared_preferences` backed store and
/// in tests with [InMemoryKeyValueStore].
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (Ref ref) => InMemoryKeyValueStore(),
);

/// Reads and writes [AppSettings].
class SettingsController extends Notifier<AppSettings> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  @override
  AppSettings build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    return AppSettings(
      localeMode: LocaleMode.fromStorage(
        store.getString(PreferenceKeys.localeMode),
      ),
      themeMode: _themeModeFromStorage(
        store.getString(PreferenceKeys.themeMode),
      ),
      accentPalette: AccentPalette.fromStorage(
        store.getString(PreferenceKeys.accentPalette),
      ),
      displayDensity: DisplayDensity.fromStorage(
        store.getString(PreferenceKeys.displayDensity),
      ),
      reducedMotion: store.getInt(PreferenceKeys.reducedMotion) == 1,
      navigation: NavigationConfig.fromStorage(
        store.getStringList(PreferenceKeys.navigationMiddle),
      ),
      dashboard: DashboardConfig.fromStorage(
        order: store.getStringList(PreferenceKeys.dashboardCardOrder),
        hidden: store.getStringList(PreferenceKeys.dashboardHiddenCards),
      ),
      preferredCanteenSlug: store.getString(PreferenceKeys.preferredCanteen),
      timetableGroupId: store.getString(PreferenceKeys.preferredTimetableGroup),
      defaultBuildingKey: store.getString(PreferenceKeys.defaultBuilding),
      onboardingCompleted:
          store.getInt(PreferenceKeys.onboardingCompleted) == 1,
      mailDownloadAttachments:
          store.getInt(PreferenceKeys.mailDownloadAttachments) == 1,
    );
  }

  Future<void> setLocaleMode(LocaleMode mode) async {
    state = state.copyWith(localeMode: mode);
    await _store.setString(PreferenceKeys.localeMode, mode.storageValue);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setString(PreferenceKeys.themeMode, _themeModeToStorage(mode));
  }

  Future<void> setPreferredCanteen(String? slug) async {
    if (slug == null) {
      state = state.copyWith(clearPreferredCanteen: true);
      await _store.remove(PreferenceKeys.preferredCanteen);
      return;
    }
    state = state.copyWith(preferredCanteenSlug: slug);
    await _store.setString(PreferenceKeys.preferredCanteen, slug);
  }

  /// Stores the **Campus** UUID of the chosen timetable group.
  Future<void> setTimetableGroup(String? groupId) async {
    if (groupId == null) {
      state = state.copyWith(clearTimetableGroup: true);
      await _store.remove(PreferenceKeys.preferredTimetableGroup);
      return;
    }
    state = state.copyWith(timetableGroupId: groupId);
    await _store.setString(PreferenceKeys.preferredTimetableGroup, groupId);
  }

  Future<void> setAccentPalette(AccentPalette palette) async {
    state = state.copyWith(accentPalette: palette);
    await _store.setString(PreferenceKeys.accentPalette, palette.storageValue);
  }

  Future<void> setDisplayDensity(DisplayDensity density) async {
    state = state.copyWith(displayDensity: density);
    await _store.setString(PreferenceKeys.displayDensity, density.storageValue);
  }

  Future<void> setReducedMotion(bool enabled) async {
    state = state.copyWith(reducedMotion: enabled);
    await _store.setInt(PreferenceKeys.reducedMotion, enabled ? 1 : 0);
  }

  /// Stores the navigation bar's three middle entries.
  ///
  /// The wish list is normalised first, so an invalid combination cannot be
  /// persisted at all — the repair happens before the write, not on the next
  /// read.
  Future<void> setNavigationMiddle(Iterable<AppSection> sections) async {
    final NavigationConfig config = NavigationConfig.of(sections);
    state = state.copyWith(navigation: config);
    await _store.setStringList(
      PreferenceKeys.navigationMiddle,
      config.toStorage(),
    );
  }

  Future<void> setDashboard(DashboardConfig config) async {
    state = state.copyWith(dashboard: config);
    await _store.setStringList(
      PreferenceKeys.dashboardCardOrder,
      config.orderToStorage(),
    );
    await _store.setStringList(
      PreferenceKeys.dashboardHiddenCards,
      config.hiddenToStorage(),
    );
  }

  Future<void> setDefaultBuilding(String? buildingKey) async {
    if (buildingKey == null) {
      state = state.copyWith(clearDefaultBuilding: true);
      await _store.remove(PreferenceKeys.defaultBuilding);
      return;
    }
    state = state.copyWith(defaultBuildingKey: buildingKey);
    await _store.setString(PreferenceKeys.defaultBuilding, buildingKey);
  }

  /// Marks the onboarding as answered — completed or deliberately skipped.
  Future<void> setOnboardingCompleted(bool completed) async {
    state = state.copyWith(onboardingCompleted: completed);
    await _store.setInt(PreferenceKeys.onboardingCompleted, completed ? 1 : 0);
  }

  /// Clears every setting this controller owns and returns to the defaults.
  ///
  /// Scoped on purpose: it resets **presentation and preferences**, not the
  /// secure stores behind mail, grades and Moodle. Those hold credentials and
  /// are removed through their own "remove account" action, which is the only
  /// place that can also clear their encrypted caches.
  Future<void> resetLocalPreferences() async {
    for (final String key in <String>[
      PreferenceKeys.localeMode,
      PreferenceKeys.themeMode,
      PreferenceKeys.accentPalette,
      PreferenceKeys.displayDensity,
      PreferenceKeys.reducedMotion,
      PreferenceKeys.navigationMiddle,
      PreferenceKeys.dashboardCardOrder,
      PreferenceKeys.dashboardHiddenCards,
      PreferenceKeys.preferredCanteen,
      PreferenceKeys.preferredTimetableGroup,
      PreferenceKeys.defaultBuilding,
      PreferenceKeys.onboardingCompleted,
      PreferenceKeys.mailDownloadAttachments,
    ]) {
      await _store.remove(key);
    }
    state = const AppSettings();
  }

  Future<void> setMailDownloadAttachments(bool enabled) async {
    state = state.copyWith(mailDownloadAttachments: enabled);
    await _store.setInt(
      PreferenceKeys.mailDownloadAttachments,
      enabled ? 1 : 0,
    );
  }

  static ThemeMode _themeModeFromStorage(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _themeModeToStorage(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
