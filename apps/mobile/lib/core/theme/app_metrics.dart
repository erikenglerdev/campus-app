// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import 'app_dimensions.dart';

/// Spacing and sizing of the app's layout, as one typed token set.
///
/// There is exactly **one** set of values and no runtime choice. The app used
/// to offer a "comfortable" and a "compact" density; the compact one won,
/// because it is what a phone actually needs, and a preference that only makes
/// the app roomier at the cost of what fits is a question nobody benefits from
/// having to answer.
///
/// Screens read these through `context.metrics` rather than reaching for raw
/// constants, so the spacing of the whole app stays one decision instead of a
/// number repeated in fifty widgets.
///
/// [listRowMinHeight] is deliberately pinned to [AppSizes.minTouchTarget]: the
/// tightest the layout may ever get is still a target a finger can hit.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({
    required this.screenPadding,
    required this.cardPadding,
    required this.cardGap,
    required this.sectionGap,
    required this.listRowMinHeight,
    required this.cardRadius,
  });

  /// Horizontal padding of a screen's content column.
  final double screenPadding;

  /// Inner padding of a card or panel.
  final double cardPadding;

  /// Vertical gap between two cards in a list.
  final double cardGap;

  /// Vertical gap between two sections of a screen.
  final double sectionGap;

  /// Minimum height of a tappable list row. Never below
  /// [AppSizes.minTouchTarget].
  final double listRowMinHeight;

  final double cardRadius;

  /// The one set the app uses.
  static const AppMetrics standard = AppMetrics(
    screenPadding: AppSpacing.md,
    cardPadding: AppSpacing.md,
    cardGap: AppSpacing.sm,
    sectionGap: AppSpacing.lg,
    listRowMinHeight: AppSizes.minTouchTarget,
    cardRadius: AppRadius.md,
  );

  @override
  AppMetrics copyWith({
    double? screenPadding,
    double? cardPadding,
    double? cardGap,
    double? sectionGap,
    double? listRowMinHeight,
    double? cardRadius,
  }) {
    return AppMetrics(
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
      Theme.of(this).extension<AppMetrics>() ?? AppMetrics.standard;
}
