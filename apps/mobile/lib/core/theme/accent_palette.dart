// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The curated accent palettes a user can choose from.
///
/// Deliberately a **closed set**, not a free colour picker. Every value here
/// was computed against the WCAG relative-luminance formula so that each
/// palette clears 4.5:1 for every foreground/background pair the app renders,
/// in light *and* dark. A free picker cannot promise that — it would let a
/// user quietly break the contrast guarantees the project commits to.
///
/// `campusViolet` is the canonical brand palette and stays the default; the
/// others only replace the brand family (primary, its container and their
/// foregrounds). Backgrounds, text, success and error are unchanged, so a
/// palette switch can never affect legibility of body copy.
///
/// Extending this enum means adding a value here — the contrast test iterates
/// over [AccentPalette.values], so a new palette that fails is a failing test,
/// never a shipped accessibility regression.
enum AccentPalette {
  campusViolet(
    storageValue: 'campus-violet',
    light: AccentBrand(
      primary: Color(0xFF5B3FD0),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF3F2A78),
      primaryContainer: Color(0xFFEEEAFE),
      onPrimaryContainer: Color(0xFF3F2A78),
    ),
    dark: AccentBrand(
      primary: Color(0xFFB9A8FF),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFD8CEFF),
      primaryContainer: Color(0xFF2C2555),
      onPrimaryContainer: Color(0xFFD8CEFF),
    ),
  ),
  oceanBlue(
    storageValue: 'ocean-blue',
    light: AccentBrand(
      primary: Color(0xFF2F70C6),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF22426D),
      primaryContainer: Color(0xFFECF4FD),
      onPrimaryContainer: Color(0xFF22426D),
    ),
    dark: AccentBrand(
      primary: Color(0xFF5A91D8),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFC6D8F1),
      primaryContainer: Color(0xFF233852),
      onPrimaryContainer: Color(0xFFC6D8F1),
    ),
  ),
  deepTeal(
    storageValue: 'deep-teal',
    light: AccentBrand(
      primary: Color(0xFF147B77),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF226D6A),
      primaryContainer: Color(0xFFECFDFD),
      onPrimaryContainer: Color(0xFF226D6A),
    ),
    dark: AccentBrand(
      primary: Color(0xFF50E2DE),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFC6F1EF),
      primaryContainer: Color(0xFF235251),
      onPrimaryContainer: Color(0xFFC6F1EF),
    ),
  ),
  freshGreen(
    storageValue: 'fresh-green',
    light: AccentBrand(
      primary: Color(0xFF217D47),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF226D41),
      primaryContainer: Color(0xFFECFDF3),
      onPrimaryContainer: Color(0xFF226D41),
    ),
    dark: AccentBrand(
      primary: Color(0xFF5ED48F),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFC6F1D8),
      primaryContainer: Color(0xFF235237),
      onPrimaryContainer: Color(0xFFC6F1D8),
    ),
  ),
  brightMagenta(
    storageValue: 'bright-magenta',
    light: AccentBrand(
      primary: Color(0xFFC5347D),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF6D2247),
      primaryContainer: Color(0xFFFDECF5),
      onPrimaryContainer: Color(0xFF6D2247),
    ),
    dark: AccentBrand(
      primary: Color(0xFFD45E99),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFF1C6DB),
      primaryContainer: Color(0xFF52233B),
      onPrimaryContainer: Color(0xFFF1C6DB),
    ),
  ),
  warmAmber(
    storageValue: 'warm-amber',
    light: AccentBrand(
      primary: Color(0xFFA75C1B),
      onPrimary: Color(0xFFFFFFFF),
      primaryDark: Color(0xFF6D4522),
      primaryContainer: Color(0xFFFDF4EC),
      onPrimaryContainer: Color(0xFF6D4522),
    ),
    dark: AccentBrand(
      primary: Color(0xFFE29450),
      onPrimary: Color(0xFF171A21),
      primaryDark: Color(0xFFF1DAC6),
      primaryContainer: Color(0xFF523923),
      onPrimaryContainer: Color(0xFFF1DAC6),
    ),
  );

  const AccentPalette({
    required this.storageValue,
    required this.light,
    required this.dark,
  });

  /// Stable identifier written to local storage. Never the enum index — a
  /// reordered enum must not silently change everyone's chosen colour.
  final String storageValue;

  final AccentBrand light;
  final AccentBrand dark;

  /// The project default. Also the fallback for an unknown stored value, so a
  /// downgrade or a hand-edited preference cannot leave the app unthemed.
  static const AccentPalette fallback = AccentPalette.campusViolet;

  static AccentPalette fromStorage(String? value) {
    for (final AccentPalette palette in AccentPalette.values) {
      if (palette.storageValue == value) return palette;
    }
    return fallback;
  }

  /// Applies this palette to a base colour set.
  AppColors applyTo(AppColors base) {
    final AccentBrand brand = base.brightness == Brightness.dark ? dark : light;
    return base.copyWith(
      primary: brand.primary,
      onPrimary: brand.onPrimary,
      primaryDark: brand.primaryDark,
      primaryContainer: brand.primaryContainer,
      onPrimaryContainer: brand.onPrimaryContainer,
      // The tinted "variant" surface is the brand container in this design, so
      // it has to follow the palette or chips would keep the old brand hue.
      surfaceVariant: base.brightness == Brightness.dark
          ? base.surfaceVariant
          : brand.primaryContainer,
      onSurfaceVariant: base.brightness == Brightness.dark
          ? base.onSurfaceVariant
          : brand.onPrimaryContainer,
    );
  }
}

/// The brand family of one palette in one brightness.
///
/// Public because [AccentPalette] exposes it; the contrast test reads these
/// values directly rather than re-deriving them.
@immutable
class AccentBrand {
  const AccentBrand({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color primaryContainer;
  final Color onPrimaryContainer;
}
