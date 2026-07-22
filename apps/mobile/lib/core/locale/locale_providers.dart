// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/settings_controller.dart';
import 'locale_mode.dart';

/// The locale the device currently reports, narrowed to a supported locale.
///
/// Updated by the app shell through [SystemLocaleController.update] when the
/// platform reports a locale change.
class SystemLocaleController extends Notifier<Locale> {
  @override
  Locale build() =>
      AppLocales.resolve(WidgetsBinding.instance.platformDispatcher.locales);

  void update(List<Locale>? locales) {
    final Locale resolved = AppLocales.resolve(locales);
    if (resolved != state) state = resolved;
  }
}

final NotifierProvider<SystemLocaleController, Locale> systemLocaleProvider =
    NotifierProvider<SystemLocaleController, Locale>(
      SystemLocaleController.new,
    );

/// The locale that is actually in effect: the manual override if there is one,
/// otherwise the system locale, otherwise `de`.
final Provider<Locale> activeLocaleProvider = Provider<Locale>((Ref ref) {
  final LocaleMode mode = ref.watch(
    settingsProvider.select((AppSettings settings) => settings.localeMode),
  );
  return mode.locale ?? ref.watch(systemLocaleProvider);
});

/// `de` or `en` — the value sent to the API and used for intl formatting.
final Provider<String> localeCodeProvider = Provider<String>(
  (Ref ref) => ref.watch(activeLocaleProvider).languageCode,
);
