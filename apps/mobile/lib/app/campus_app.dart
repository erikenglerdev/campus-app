// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/locale/locale_mode.dart';
import '../core/locale/locale_providers.dart';
import '../core/prefs/settings_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/mail/application/mail_account_controller.dart';
import '../features/mail/application/mail_sync_controller.dart';
import '../l10n/l10n.dart';
import 'app_router.dart';

/// Root widget of the app.
///
/// Owns the theme mode, the locale resolution and the router. It also forwards
/// platform locale changes into [SystemLocaleController], so "follow the system
/// language" keeps working while the app is running.
class CampusApp extends ConsumerStatefulWidget {
  const CampusApp({super.key});

  @override
  ConsumerState<CampusApp> createState() => _CampusAppState();
}

class _CampusAppState extends ConsumerState<CampusApp>
    with WidgetsBindingObserver {
  Timer? _mailSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sync the mailbox once on app start and then every 10 minutes while the
    // app runs. syncNow() no-ops when signed out, so this is safe to fire
    // unconditionally.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMail());
    _mailSyncTimer = Timer.periodic(kMailSyncInterval, (_) => _syncMail());
  }

  @override
  void dispose() {
    _mailSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncMail() {
    if (!mounted) return;
    ref.read(mailSyncControllerProvider.notifier).syncNow();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.read(systemLocaleProvider.notifier).update(locales);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(settingsProvider);

    // Also sync as soon as an account becomes available (a fresh sign-in, or a
    // stored account restored at startup after the async load resolves).
    ref.listen<AsyncValue<MailAccountState>>(mailAccountControllerProvider, (
      AsyncValue<MailAccountState>? previous,
      AsyncValue<MailAccountState> next,
    ) {
      final bool wasSignedIn = previous?.value?.isSignedIn ?? false;
      if (!wasSignedIn && (next.value?.isSignedIn ?? false)) {
        _syncMail();
      }
    });

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.localeMode.locale,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback:
          (List<Locale>? locales, Iterable<Locale> supported) =>
              AppLocales.resolve(locales),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
