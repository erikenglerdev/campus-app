// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:ui' show Locale;

/// Supported locales of the app. `de` is default **and** fallback.
abstract final class AppLocales {
  static const Locale german = Locale('de');
  static const Locale english = Locale('en');

  /// Default and fallback locale.
  static const Locale fallback = german;

  static const List<Locale> supported = <Locale>[german, english];

  /// Resolves a device locale list against the supported locales.
  ///
  /// Anything that is neither `de` nor `en` falls back to [fallback].
  static Locale resolve(List<Locale>? deviceLocales) {
    if (deviceLocales == null) return fallback;
    for (final Locale locale in deviceLocales) {
      for (final Locale supportedLocale in supported) {
        if (supportedLocale.languageCode == locale.languageCode) {
          return supportedLocale;
        }
      }
    }
    return fallback;
  }
}

/// The user's language preference. `system` follows the device language.
enum LocaleMode {
  system('system'),
  german('de'),
  english('en');

  const LocaleMode(this.storageValue);

  final String storageValue;

  /// The explicit [Locale] this mode pins the app to, or `null` for `system`.
  Locale? get locale => switch (this) {
    LocaleMode.system => null,
    LocaleMode.german => AppLocales.german,
    LocaleMode.english => AppLocales.english,
  };

  static LocaleMode fromStorage(String? value) {
    for (final LocaleMode mode in LocaleMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return LocaleMode.system;
  }
}
