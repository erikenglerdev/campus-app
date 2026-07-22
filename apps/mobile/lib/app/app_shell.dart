// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_dimensions.dart';
import '../l10n/l10n.dart';

/// Bottom navigation shell holding the five top-level sections.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Semantics(
        label: l10n.navigationSemanticLabel,
        container: true,
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (int index) =>
              navigationShell.goBranch(index, initialLocation: false),
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: const Icon(Icons.article_outlined),
              selectedIcon: const Icon(Icons.article),
              label: l10n.navNews,
              tooltip: l10n.navNews,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: l10n.navTimetable,
              tooltip: l10n.navTimetable,
            ),
            NavigationDestination(
              icon: const Icon(Icons.restaurant_outlined),
              selectedIcon: const Icon(Icons.restaurant),
              label: l10n.navCanteen,
              tooltip: l10n.navCanteen,
            ),
            NavigationDestination(
              icon: const Icon(Icons.contact_support_outlined),
              selectedIcon: const Icon(Icons.contact_support),
              label: l10n.navContacts,
              tooltip: l10n.navContacts,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.navSettings,
              tooltip: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Height reserved for the navigation bar so touch targets stay >= 48dp.
const double kNavigationBarHeight = AppSizes.minTouchTarget + AppSpacing.xl;
