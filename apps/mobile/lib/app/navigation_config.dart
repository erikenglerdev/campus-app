// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import 'app_sections.dart';

/// Which areas the bottom navigation bar shows.
///
/// The bar is always five entries: **Today** first, **More** last, and three
/// slots the user picks. Those two are fixed for a reason — Today is the
/// intended entry point, and More is the only guarantee that every area stays
/// reachable no matter what the middle slots contain.
///
/// Everything that reads a stored configuration goes through [fromStorage],
/// which *repairs* rather than rejects: an unknown identifier from a removed
/// area, a duplicate, a wrong length or a hand-edited preference must never
/// leave a user with a broken navigation bar. Storage is untrusted input.
@immutable
class NavigationConfig {
  const NavigationConfig._(this.middle);

  /// The three user-chosen areas, in bar order.
  final List<AppSection> middle;

  /// How many slots the user controls.
  static const int middleSlots = 3;

  static const NavigationConfig defaults = NavigationConfig._(<AppSection>[
    AppSection.calendar,
    AppSection.canteen,
    AppSection.news,
  ]);

  /// Builds a valid configuration from any wish list.
  ///
  /// Fixed sections are removed, duplicates collapsed, the list truncated to
  /// [middleSlots] and any remaining gap filled from the defaults and then the
  /// rest of the catalogue — so the result is always exactly three distinct,
  /// configurable areas.
  factory NavigationConfig.of(Iterable<AppSection> wanted) {
    final List<AppSection> chosen = <AppSection>[];
    void take(AppSection section) {
      if (chosen.length >= middleSlots) return;
      if (section.placement != SectionPlacement.configurable) return;
      if (chosen.contains(section)) return;
      chosen.add(section);
    }

    wanted.forEach(take);
    // Fill from the defaults first so a half-configured bar still looks like
    // the product's intended one, then from the remaining catalogue.
    defaults.middle.forEach(take);
    AppSection.configurable.forEach(take);
    return NavigationConfig._(List<AppSection>.unmodifiable(chosen));
  }

  /// Reads a stored configuration. `null` — a first launch — yields
  /// [defaults].
  factory NavigationConfig.fromStorage(List<String>? stored) {
    if (stored == null) return defaults;
    return NavigationConfig.of(
      stored
          .map(AppSection.fromStorage)
          .whereType<AppSection>()
          .toList(growable: false),
    );
  }

  List<String> toStorage() =>
      middle.map((AppSection s) => s.storageValue).toList(growable: false);

  /// The full bar, fixed entries included.
  List<AppSection> get destinations => <AppSection>[
    AppSection.today,
    ...middle,
    AppSection.more,
  ];

  /// Whether this configuration is one the app can actually render.
  ///
  /// Always true for anything [NavigationConfig.of] produced; kept as an
  /// explicit predicate so tests state the invariant rather than assume it.
  bool get isValid =>
      middle.length == middleSlots &&
      middle.toSet().length == middleSlots &&
      middle.every(
        (AppSection s) => s.placement == SectionPlacement.configurable,
      );

  /// Index of the tab owning [route], or `-1` when no tab does.
  int indexOfRoute(String route) {
    final List<AppSection> all = destinations;
    for (int i = 0; i < all.length; i++) {
      if (all[i].route == route) return i;
    }
    return -1;
  }

  @override
  bool operator ==(Object other) =>
      other is NavigationConfig && listEquals(other.middle, middle);

  @override
  int get hashCode => Object.hashAll(middle);

  @override
  String toString() =>
      'NavigationConfig(${middle.map((AppSection s) => s.storageValue).join(', ')})';
}
