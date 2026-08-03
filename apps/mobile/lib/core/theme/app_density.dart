// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import 'app_dimensions.dart';

/// How much breathing room the interface gives its content.
///
/// Two named steps rather than a slider: every value below was chosen so that
/// **compact still clears the 48dp touch target**. A continuous control would
/// let a user shrink the app past that, which the project rules forbid.
enum DisplayDensity {
  /// Roomier. The default — easier to hit, easier to scan.
  comfortable('comfortable'),

  /// Tighter. Fits noticeably more onto a 320 px-wide phone without ever
  /// going below the minimum touch target.
  compact('compact');

  const DisplayDensity(this.storageValue);

  /// Stable identifier written to local storage, never the enum index.
  final String storageValue;

  static const DisplayDensity fallback = DisplayDensity.comfortable;

  static DisplayDensity fromStorage(String? value) {
    for (final DisplayDensity density in DisplayDensity.values) {
      if (density.storageValue == value) return density;
    }
    return fallback;
  }

  bool get isCompact => this == DisplayDensity.compact;
}

/// Spacing and sizing that changes with [DisplayDensity].
///
/// Screens read these through `context.metrics` instead of picking between two
/// constants themselves, so density stays a single decision rather than a
/// condition repeated in every widget.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({
    required this.density,
    required this.screenPadding,
    required this.cardPadding,
    required this.cardGap,
    required this.sectionGap,
    required this.listRowMinHeight,
    required this.cardRadius,
  });

  final DisplayDensity density;

  /// Horizontal padding of a screen's content column.
  final double screenPadding;

  /// Inner padding of a card or panel.
  final double cardPadding;

  /// Vertical gap between two cards in a list.
  final double cardGap;

  /// Vertical gap between two sections of a screen.
  final double sectionGap;

  /// Minimum height of a tappable list row. Never below
  /// [AppSizes.minTouchTarget], in either density.
  final double listRowMinHeight;

  final double cardRadius;

  static const AppMetrics comfortable = AppMetrics(
    density: DisplayDensity.comfortable,
    screenPadding: AppSpacing.lg,
    cardPadding: AppSpacing.lg,
    cardGap: AppSpacing.md,
    sectionGap: AppSpacing.xl,
    listRowMinHeight: 56,
    cardRadius: AppRadius.lg,
  );

  static const AppMetrics compact = AppMetrics(
    density: DisplayDensity.compact,
    screenPadding: AppSpacing.md,
    cardPadding: AppSpacing.md,
    cardGap: AppSpacing.sm,
    sectionGap: AppSpacing.lg,
    listRowMinHeight: AppSizes.minTouchTarget,
    cardRadius: AppRadius.md,
  );

  static AppMetrics of(DisplayDensity density) =>
      density.isCompact ? compact : comfortable;

  @override
  AppMetrics copyWith({
    DisplayDensity? density,
    double? screenPadding,
    double? cardPadding,
    double? cardGap,
    double? sectionGap,
    double? listRowMinHeight,
    double? cardRadius,
  }) {
    return AppMetrics(
      density: density ?? this.density,
      screenPadding: screenPadding ?? this.screenPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      cardGap: cardGap ?? this.cardGap,
      sectionGap: sectionGap ?? this.sectionGap,
      listRowMinHeight: listRowMinHeight ?? this.listRowMinHeight,
      cardRadius: cardRadius ?? this.cardRadius,
    );
  }

  @override
  AppMetrics lerp(covariant AppMetrics? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return AppMetrics(
      density: t < 0.5 ? density : other.density,
      screenPadding: mix(screenPadding, other.screenPadding),
      cardPadding: mix(cardPadding, other.cardPadding),
      cardGap: mix(cardGap, other.cardGap),
      sectionGap: mix(sectionGap, other.sectionGap),
      listRowMinHeight: mix(listRowMinHeight, other.listRowMinHeight),
      cardRadius: mix(cardRadius, other.cardRadius),
    );
  }
}

/// Reads [AppMetrics] off the theme.
extension AppMetricsContext on BuildContext {
  AppMetrics get metrics =>
      Theme.of(this).extension<AppMetrics>() ?? AppMetrics.comfortable;
}
