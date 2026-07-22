// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/locale_mode.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../canteen/application/canteen_providers.dart';
import '../../canteen/data/canteen_models.dart';
import '../../canteen/presentation/canteen_picker_sheet.dart';
import '../../news/application/channel_subscriptions.dart';

/// Local settings. Everything here stays on the device — the app works
/// entirely without a user account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppSettings settings = ref.watch(settingsProvider);
    final int selectedChannels = ref
        .watch(channelSubscriptionProvider)
        .selectedSlugs
        .length;
    final List<Canteen> canteens =
        ref.watch(canteensProvider).value?.value ?? const <Canteen>[];
    final String? canteenSlug = ref.watch(selectedCanteenSlugProvider);
    final String canteenName = canteens
        .where((Canteen canteen) => canteen.slug == canteenSlug)
        .map((Canteen canteen) => canteen.displayName)
        .firstOrNull ??
        l10n.settingsPreferredCanteenNone;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: <Widget>[
          _SectionHeader(title: l10n.settingsSectionAppearance),
          _LanguageTile(settings: settings),
          _ThemeTile(settings: settings),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionContent),
          ListTile(
            leading: const Icon(Icons.rss_feed_outlined),
            title: Text(l10n.settingsChannels),
            subtitle: Text(l10n.newsChannelCountLabel(selectedChannels)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.channels),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(l10n.settingsPreferredCanteen),
            subtitle: Text(canteenName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showCanteenPickerSheet(context),
          ),
          const Divider(),
          _SectionHeader(title: l10n.settingsSectionLegal),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.about),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsImprint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.imprint),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.privacy),
          ),
        ],
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    String label(LocaleMode mode) => switch (mode) {
      LocaleMode.system => l10n.settingsLanguageSystem,
      LocaleMode.german => l10n.settingsLanguageGerman,
      LocaleMode.english => l10n.settingsLanguageEnglish,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        RadioGroup<LocaleMode>(
          groupValue: settings.localeMode,
          onChanged: (LocaleMode? value) {
            if (value == null) return;
            ref.read(settingsProvider.notifier).setLocaleMode(value);
          },
          child: Column(
            children: <Widget>[
              for (final LocaleMode mode in LocaleMode.values)
                RadioListTile<LocaleMode>.adaptive(
                  value: mode,
                  title: Text(label(mode)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    String label(ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.settingsThemeSystem,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.dark => l10n.settingsThemeDark,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        RadioGroup<ThemeMode>(
          groupValue: settings.themeMode,
          onChanged: (ThemeMode? value) {
            if (value == null) return;
            ref.read(settingsProvider.notifier).setThemeMode(value);
          },
          child: Column(
            children: <Widget>[
              for (final ThemeMode mode in ThemeMode.values)
                RadioListTile<ThemeMode>.adaptive(
                  value: mode,
                  title: Text(label(mode)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
