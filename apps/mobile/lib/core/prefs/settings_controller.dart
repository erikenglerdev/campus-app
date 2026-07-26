// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/locale_mode.dart';
import 'key_value_store.dart';
import 'preference_keys.dart';

/// All locally persisted user settings that are plain scalars.
class AppSettings {
  const AppSettings({
    this.localeMode = LocaleMode.system,
    this.themeMode = ThemeMode.system,
    this.preferredCanteenSlug,
    this.timetableGroupId,
    this.mailDownloadAttachments = false,
  });

  final LocaleMode localeMode;
  final ThemeMode themeMode;

  /// Slug of the canteen the user prefers, or `null` for "not chosen yet".
  final String? preferredCanteenSlug;

  /// **Campus** UUID of the chosen timetable group, or `null` for "not chosen
  /// yet". The app never stores an upstream identifier.
  final String? timetableGroupId;

  /// When true, the mail sync downloads attachment bytes too, so attachments
  /// are available offline. Off by default to keep the cache small.
  final bool mailDownloadAttachments;

  AppSettings copyWith({
    LocaleMode? localeMode,
    ThemeMode? themeMode,
    String? preferredCanteenSlug,
    bool clearPreferredCanteen = false,
    String? timetableGroupId,
    bool clearTimetableGroup = false,
    bool? mailDownloadAttachments,
  }) {
    return AppSettings(
      localeMode: localeMode ?? this.localeMode,
      themeMode: themeMode ?? this.themeMode,
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
      preferredCanteenSlug: store.getString(PreferenceKeys.preferredCanteen),
      timetableGroupId: store.getString(PreferenceKeys.preferredTimetableGroup),
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
