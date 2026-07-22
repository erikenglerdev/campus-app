// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

/// Typed spacing scale. Screens never use raw magic numbers for layout.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Typed corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Accessibility related dimensions.
abstract final class AppSizes {
  /// Minimum interactive target edge length. Required by the project rules.
  static const double minTouchTarget = 48;

  /// Hairline / border width used for outlines.
  static const double hairline = 1;

  /// Accent bar width used by status banners so state is never colour-only.
  static const double statusBar = 4;

  /// Icon size used in list rows.
  static const double icon = 24;

  /// Icon size used in empty/error states.
  static const double illustrationIcon = 48;
}
