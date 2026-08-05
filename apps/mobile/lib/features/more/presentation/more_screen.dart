// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_modules.dart';
import '../../../app/navigation_config.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../l10n/l10n.dart';

/// The "Mehr" hub: everything the bottom bar has no room for.
///
/// The list is **derived** from the module catalogue, grouped by the category
/// each module declares. That is what makes the bar safe to configure:
/// whichever four modules a user pins, every other one turns up here under its
/// own heading. A hand-written list looks identical on a default install and
/// quietly strands whatever nobody thought to add.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final NavigationConfig navigation = ref.watch(
      settingsProvider.select((AppSettings s) => s.navigation),
    );
    final List<MoreCategoryEntry> entries = navigation.moreEntries;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreTitle)),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: metrics.cardGap),
        children: <Widget>[
          for (final MoreCategoryEntry entry in entries) ...<Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.screenPadding,
                metrics.sectionGap,
                metrics.screenPadding,
                AppSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  entry.category.label(l10n),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            for (final AppModule module in entry.modules)
              _ModuleTile(module: module, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.l10n});

  final AppModule module;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = module.subtitle(l10n);
    return ListTile(
      leading: Icon(module.icon),
      title: Text(module.title(l10n)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      // Pushed rather than switched to: a module opened from here belongs to
      // this stack, which is what keeps "Mehr" highlighted while it is open.
      onTap: () => GoRouter.of(context).push(module.route),
    );
  }
}
