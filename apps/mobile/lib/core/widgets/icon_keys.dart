// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

/// Maps the API's free-form `iconKey` onto a bundled Material icon.
///
/// The API may introduce a new key at any time without an app release, so an
/// unknown key must never break a screen: it resolves to [fallback], a neutral
/// icon that carries no wrong meaning.
abstract final class IconKeys {
  /// Neutral icon used for every unknown or missing key.
  static const IconData fallback = Icons.label_outline;

  static const Map<String, IconData> _icons = <String, IconData>{
    'campus': Icons.school_outlined,
    'news': Icons.article_outlined,
    'announcement': Icons.campaign_outlined,
    'event': Icons.event_outlined,
    'faculty': Icons.account_balance_outlined,
    'students-council': Icons.groups_outlined,
    'service': Icons.support_agent_outlined,
    'library': Icons.local_library_outlined,
    'canteen': Icons.restaurant_outlined,
    'housing': Icons.home_work_outlined,
    'finance': Icons.payments_outlined,
    'international': Icons.public_outlined,
    'health': Icons.health_and_safety_outlined,
    'sports': Icons.sports_soccer_outlined,
    'it': Icons.devices_outlined,
    'career': Icons.work_outline,
  };

  /// Resolves [key] to an icon, falling back to [fallback].
  static IconData resolve(String? key) {
    if (key == null) return fallback;
    return _icons[key.trim().toLowerCase()] ?? fallback;
  }

  /// Whether [key] is a key the app knows. Used by tests.
  static bool isKnown(String? key) =>
      key != null && _icons.containsKey(key.trim().toLowerCase());
}
