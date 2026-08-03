// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs/settings_controller.dart';
import '../core/theme/app_dimensions.dart';
import '../l10n/l10n.dart';
import 'app_sections.dart';
import 'navigation_config.dart';

/// Bottom navigation shell.
///
/// The router owns **one branch per [AppSection]**, so a branch index is just
/// the section's index. This widget shows five of them: Today, the user's three
/// choices and More.
///
/// A section the user navigated to without it being in the bar — grades opened
/// from More, say — has no tab of its own. Rather than leaving nothing
/// selected, the bar then highlights More, which is where that section was
/// reached from and where it can be reached again.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NavigationConfig config = ref.watch(
      settingsProvider.select((AppSettings s) => s.navigation),
    );
    final List<AppSection> destinations = config.destinations;

    // Branch index -> bar index. `-1` means "this branch has no tab".
    int selected = destinations.indexWhere(
      (AppSection s) => s.index == navigationShell.currentIndex,
    );
    if (selected == -1) selected = destinations.indexOf(AppSection.more);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Semantics(
        label: l10n.navigationSemanticLabel,
        container: true,
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (int barIndex) => navigationShell.goBranch(
            destinations[barIndex].index,
            // Tapping the tab you are already on returns to that section's
            // root — the behaviour both platforms have trained users to expect.
            initialLocation:
                destinations[barIndex].index == navigationShell.currentIndex,
          ),
          destinations: <NavigationDestination>[
            for (final AppSection section in destinations)
              NavigationDestination(
                icon: Icon(section.icon),
                selectedIcon: Icon(section.selectedIcon),
                label: section.label(l10n),
                tooltip: section.label(l10n),
              ),
          ],
        ),
      ),
    );
  }
}

/// Height reserved for the navigation bar so touch targets stay >= 48dp.
const double kNavigationBarHeight = AppSizes.minTouchTarget + AppSpacing.xl;
