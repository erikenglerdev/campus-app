// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_sections.dart';
import '../../../app/navigation_config.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';

/// Picks the three middle entries of the bottom navigation bar.
///
/// Today and More are shown as fixed, disabled rows rather than hidden: the
/// user can see the whole bar they are configuring, and why two of it cannot
/// be changed.
///
/// The screen edits a **local draft** and only writes through once exactly
/// three areas are selected.
///
/// Writing on every tap looked simpler and did not work: the stored
/// configuration is always repaired to exactly three, so unchecking one
/// immediately refilled it from the defaults and the checkbox appeared to do
/// nothing. A draft lets the user take one away, put another back, and commit
/// a state the store can actually hold.
class NavigationSettingsScreen extends ConsumerStatefulWidget {
  const NavigationSettingsScreen({super.key});

  @override
  ConsumerState<NavigationSettingsScreen> createState() =>
      _NavigationSettingsScreenState();
}

class _NavigationSettingsScreenState
    extends ConsumerState<NavigationSettingsScreen> {
  List<AppSection>? _draft;

  List<AppSection> get _chosen =>
      _draft ?? ref.read(settingsProvider).navigation.middle;

  void _set(AppSection section, {required bool selected}) {
    final List<AppSection> next = _chosen.toList();
    if (selected) {
      if (next.length >= NavigationConfig.middleSlots) return;
      next.add(section);
    } else {
      next.remove(section);
    }
    setState(() => _draft = next);
    // Only a complete selection is a valid bar, so only that is persisted.
    if (next.length == NavigationConfig.middleSlots) {
      ref.read(settingsProvider.notifier).setNavigationMiddle(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSection> chosen = _chosen;
    final bool full = chosen.length >= NavigationConfig.middleSlots;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNavigation)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.settingsNavigationHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          // An incomplete draft is not an error, but it is not saved either —
          // say so rather than letting the user believe it was.
          if (!full)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: AppSizes.iconSmall,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.settingsSelectExactlyThree,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          _FixedRow(section: AppSection.today),
          for (final AppSection section in AppSection.configurable)
            CheckboxListTile(
              secondary: Icon(section.icon),
              title: Text(section.label(l10n)),
              value: chosen.contains(section),
              // Full and not already chosen: leave it disabled rather than
              // evicting someone else's pick behind their back.
              onChanged: full && !chosen.contains(section)
                  ? null
                  : (bool? value) => _set(section, selected: value ?? false),
            ),
          _FixedRow(section: AppSection.more),
        ],
      ),
    );
  }
}

/// A bar entry the user cannot move.
class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      leading: Icon(section.icon),
      title: Text(section.label(l10n)),
      trailing: const Icon(Icons.lock_outline),
      enabled: false,
    );
  }
}
