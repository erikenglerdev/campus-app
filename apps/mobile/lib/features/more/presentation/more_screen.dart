// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_sections.dart';
import '../../../app/navigation_config.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';

/// The "Mehr" section: everything the bottom bar has no room for.
///
/// The list is **derived** from [AppSection] rather than written out by hand.
/// That is what makes the navigation bar safe to configure: whichever three
/// areas a user pins to the middle slots, every other area turns up here. A
/// hand-written list looks identical on a default install and quietly strands
/// whatever nobody thought to add — which is exactly how the contacts section
/// became reachable only through the dashboard shortcut.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NavigationConfig navigation = ref.watch(
      settingsProvider.select((AppSettings s) => s.navigation),
    );

    // Catalogue order, minus whatever already has a tab of its own.
    final List<AppSection> sections = AppSection.configurable
        .where((AppSection s) => !navigation.middle.contains(s))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: <Widget>[
          for (final AppSection section in sections)
            _SectionTile(section: section, l10n: l10n),
          // Settings are not a section: they have no tab, cannot be pinned, and
          // therefore always belong at the end of this list.
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.moreSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.l10n});

  final AppSection section;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = section.subtitle(l10n);
    return ListTile(
      leading: Icon(section.icon),
      title: Text(section.label(l10n)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(section.route),
    );
  }
}
