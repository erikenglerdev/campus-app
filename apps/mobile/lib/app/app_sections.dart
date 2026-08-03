// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_routes.dart';

/// Every top-level area of the app, in one typed list.
///
/// This is the single source the navigation bar, the "More" screen, the
/// onboarding, the settings and the global search all read from. Adding an
/// area means adding a value here — not editing five widgets that each carry
/// their own hardcoded list and drift apart.
///
/// Labels come from `gen_l10n` on purpose: no visible text lives in this file.
enum AppSection {
  /// The day dashboard. Always the first navigation entry, never configurable.
  today(
    storageValue: 'today',
    route: AppRoutes.today,
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
    placement: SectionPlacement.fixedFirst,
  ),
  calendar(
    storageValue: 'calendar',
    route: AppRoutes.calendar,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  canteen(
    storageValue: 'canteen',
    route: AppRoutes.canteen,
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
  ),
  news(
    storageValue: 'news',
    route: AppRoutes.news,
    icon: Icons.article_outlined,
    selectedIcon: Icons.article,
  ),
  moodle(
    storageValue: 'moodle',
    route: AppRoutes.moodle,
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  mail(
    storageValue: 'mail',
    route: AppRoutes.mail,
    icon: Icons.mail_outline,
    selectedIcon: Icons.mail,
  ),
  todos(
    storageValue: 'todos',
    route: AppRoutes.todos,
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
  ),
  campusMap(
    storageValue: 'campus-map',
    route: AppRoutes.campusMap,
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
  ),
  contacts(
    storageValue: 'contacts',
    route: AppRoutes.contacts,
    icon: Icons.contact_support_outlined,
    selectedIcon: Icons.contact_support,
  ),
  grades(
    storageValue: 'grades',
    route: AppRoutes.grades,
    icon: Icons.grade_outlined,
    selectedIcon: Icons.grade,
  ),

  /// The catch-all. Always the last navigation entry, never configurable —
  /// it is how every area stays reachable regardless of the bar's contents.
  more(
    storageValue: 'more',
    route: AppRoutes.more,
    icon: Icons.more_horiz,
    selectedIcon: Icons.more,
    placement: SectionPlacement.fixedLast,
  );

  const AppSection({
    required this.storageValue,
    required this.route,
    required this.icon,
    required this.selectedIcon,
    this.placement = SectionPlacement.configurable,
  });

  /// Stable identifier written to local storage, never the enum index.
  final String storageValue;

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final SectionPlacement placement;

  /// The areas a user may put into the three configurable middle slots.
  static List<AppSection> get configurable => AppSection.values
      .where((AppSection s) => s.placement == SectionPlacement.configurable)
      .toList(growable: false);

  static AppSection? fromStorage(String? value) {
    for (final AppSection section in AppSection.values) {
      if (section.storageValue == value) return section;
    }
    return null;
  }

  /// Localised name. The only place a section's visible text comes from.
  String label(AppLocalizations l10n) => switch (this) {
    AppSection.today => l10n.navToday,
    AppSection.calendar => l10n.navCalendar,
    AppSection.canteen => l10n.navCanteen,
    AppSection.news => l10n.navNews,
    AppSection.moodle => l10n.moodleTitle,
    AppSection.mail => l10n.mailTitle,
    AppSection.todos => l10n.todosTitle,
    AppSection.campusMap => l10n.campusMapTitle,
    AppSection.contacts => l10n.navContacts,
    AppSection.grades => l10n.gradesTitle,
    AppSection.more => l10n.navMore,
  };

  /// Whether this area is a personal service that talks to an official system
  /// directly from the device.
  ///
  /// Used to keep such areas out of the public global search index and to make
  /// their dashboard cards conditional on being set up. It is a property of the
  /// area itself, so no caller has to remember the list.
  bool get isPersonalService => switch (this) {
    AppSection.mail || AppSection.grades || AppSection.moodle => true,
    _ => false,
  };
}

/// Where a section may appear in the bottom navigation bar.
enum SectionPlacement {
  /// Pinned to the first slot.
  fixedFirst,

  /// User-selectable middle slot.
  configurable,

  /// Pinned to the last slot.
  fixedLast,
}
