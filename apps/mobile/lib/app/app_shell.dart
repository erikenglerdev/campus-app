// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/prefs/settings_controller.dart';
import '../core/environment/app_environment_repository.dart';
import '../core/theme/app_dimensions.dart';
import '../core/widgets/test_environment_notice.dart';
import '../l10n/l10n.dart';
import 'app_modules.dart';
import 'navigation_config.dart';

/// Bottom navigation shell.
///
/// The router owns **one branch per [AppModule]**, in enum order, plus a final
/// branch for More. A branch index is therefore just the module's index, and
/// More is the last one — no lookup table can drift out of sync.
///
/// A module the user navigated to without it being on the bar — grades opened
/// from More, say — has no tab of its own. Rather than leaving nothing
/// selected, the bar then highlights More, which is where that module was
/// reached from and where it can be reached again.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Branch index of the More tab: one past the last pinnable module.
  ///
  /// The router lays out one branch per pinnable module, in enum order, and
  /// More last. That only works while the pinnable modules are the leading
  /// values of the enum — an invariant `app_modules_test` asserts, because
  /// breaking it would silently point every tab at the wrong screen.
  static int get moreBranchIndex => AppModule.pinnableModules.length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NavigationConfig config = ref.watch(
      settingsProvider.select((AppSettings s) => s.navigation),
    );
    final List<AppModule> tabs = config.tabs;
    final bool discloseUserTestData =
        ref.watch(appEnvironmentProvider).value?.value.userTestData ?? false;

    /// Branch index of each bar entry: the four modules, then More.
    int branchOf(int barIndex) =>
        barIndex < tabs.length ? tabs[barIndex].index : moreBranchIndex;

    // Branch index -> bar index. Anything not on the bar falls back to More.
    int selected = tabs.indexWhere(
      (AppModule m) => m.index == navigationShell.currentIndex,
    );
    if (selected == -1) selected = tabs.length;

    return Scaffold(
      body: Column(
        children: <Widget>[
          if (discloseUserTestData) const TestEnvironmentNotice(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Semantics(
        label: l10n.navigationSemanticLabel,
        container: true,
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (int barIndex) => navigationShell.goBranch(
            branchOf(barIndex),
            // Tapping the tab you are already on returns to that module's
            // root — the behaviour both platforms have trained users to expect.
            initialLocation: branchOf(barIndex) == navigationShell.currentIndex,
          ),
          destinations: <NavigationDestination>[
            for (final AppModule module in tabs)
              NavigationDestination(
                icon: Icon(module.icon),
                selectedIcon: Icon(module.selectedIcon),
                label: module.shortTitle(l10n),
                tooltip: module.title(l10n),
              ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              selectedIcon: const Icon(Icons.more_horiz),
              label: l10n.navMore,
              tooltip: l10n.navMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// Height reserved for the navigation bar so touch targets stay >= 48dp.
const double kNavigationBarHeight = AppSizes.minTouchTarget + AppSpacing.xl;
