// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

/// Central, typed colour tokens of the app.
///
/// This is the **only** place in the code base that is allowed to contain
/// colour literals. Screens and widgets read tokens through
/// `Theme.of(context).extension<AppColors>()` (see [AppColorsContext]).
///
/// ## Light palette
///
/// The light palette is the canonical brand palette of the project.
///
/// ## Dark palette — rationale
///
/// The dark palette is **not** a mechanical inversion. It keeps the brand hues
/// (violet ~257°, gold ~40°, teal-green ~163°, red ~352°) but moves them to the
/// high-lightness / medium-chroma end so they stay legible on dark surfaces,
/// and it replaces the warm paper background of the light theme with a slightly
/// blue-tinted near-black. Concretely:
///
/// * `background` #12141C and `surface` #1B1E28 form a two-step elevation
///   system. Elevation is expressed by lighter surfaces, never by shadows only.
/// * `primary` #B9A8FF is the light tint of the brand violet. It is used for
///   text, icons and outlines; when it carries text (filled buttons) the
///   foreground is the near-black `textPrimary` of the light theme.
/// * `primaryContainer` #2C2555 is a desaturated dark violet used as a *tinted
///   background only*. Its foreground is `onPrimaryContainer` #D8CEFF.
/// * `accent`, `success` and `error` are lightened so that every one of them
///   clears 4.5:1 on both `background` and `surface`.
///
/// Every foreground/background pair the app actually renders is asserted in
/// `test/core/theme/theme_contrast_test.dart` using the WCAG relative
/// luminance formula. See `README.md` for the measured table.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.onSuccess,
    required this.error,
    required this.onError,
  });

  final Brightness brightness;

  /// Primary brand colour. Carries [onPrimary] when used as a fill.
  final Color primary;
  final Color onPrimary;

  /// Darker brand shade — used for pressed states and strong emphasis.
  final Color primaryDark;

  /// Tinted brand surface. Background only, never a text colour.
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Secondary brand accent. Background only, carries [onAccent].
  final Color accent;
  final Color onAccent;

  /// App scaffold background.
  final Color background;
  final Color onBackground;

  /// Cards, sheets, list surfaces.
  final Color surface;
  final Color onSurface;

  /// Slightly raised surface, e.g. chips and inline code-like containers.
  final Color surfaceVariant;
  final Color onSurfaceVariant;

  /// Hairlines and borders. Decorative only — never the sole state carrier.
  final Color outline;

  /// Body copy on [surface] and [background].
  final Color textPrimary;

  /// Supporting copy on [surface] and [background].
  final Color textSecondary;

  /// Positive state. Always paired with an icon or a text label.
  final Color success;
  final Color onSuccess;

  /// Negative state. Always paired with an icon or a text label.
  final Color error;
  final Color onError;

  /// Canonical light palette.
  static const AppColors light = AppColors(
    brightness: Brightness.light,
    primary: Color(0xFF5B3FD0),
    onPrimary: Color(0xFFFFFFFF),
    primaryDark: Color(0xFF3F2A78),
    primaryContainer: Color(0xFFEEEAFE),
    onPrimaryContainer: Color(0xFF3F2A78),
    accent: Color(0xFFE8B44F),
    onAccent: Color(0xFF171A21),
    background: Color(0xFFF7F5F2),
    onBackground: Color(0xFF171A21),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF171A21),
    surfaceVariant: Color(0xFFEEEAFE),
    onSurfaceVariant: Color(0xFF3F2A78),
    outline: Color(0xFF626774),
    textPrimary: Color(0xFF171A21),
    textSecondary: Color(0xFF626774),
    success: Color(0xFF18856B),
    onSuccess: Color(0xFFFFFFFF),
    error: Color(0xFFC43D4D),
    onError: Color(0xFFFFFFFF),
  );

  /// Accessible dark palette — see the class doc comment for the rationale.
  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    primary: Color(0xFFB9A8FF),
    onPrimary: Color(0xFF171A21),
    primaryDark: Color(0xFFD8CEFF),
    primaryContainer: Color(0xFF2C2555),
    onPrimaryContainer: Color(0xFFD8CEFF),
    accent: Color(0xFFE8B44F),
    onAccent: Color(0xFF171A21),
    background: Color(0xFF12141C),
    onBackground: Color(0xFFF2F3F7),
    surface: Color(0xFF1B1E28),
    onSurface: Color(0xFFF2F3F7),
    surfaceVariant: Color(0xFF262A38),
    onSurfaceVariant: Color(0xFFF2F3F7),
    outline: Color(0xFFAEB4C4),
    textPrimary: Color(0xFFF2F3F7),
    textSecondary: Color(0xFFAEB4C4),
    success: Color(0xFF4FD3A8),
    onSuccess: Color(0xFF171A21),
    error: Color(0xFFFF9AA4),
    onError: Color(0xFF171A21),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primaryDark,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent,
    Color? onAccent,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? onSuccess,
    Color? error,
    Color? onError,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryDark: mix(primaryDark, other.primaryDark),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      background: mix(background, other.background),
      onBackground: mix(onBackground, other.onBackground),
      surface: mix(surface, other.surface),
      onSurface: mix(onSurface, other.onSurface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      onSurfaceVariant: mix(onSurfaceVariant, other.onSurfaceVariant),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
    );
  }
}

/// Convenient, null-safe access to [AppColors] from any widget.
extension AppColorsContext on BuildContext {
  AppColors get colors {
    final Brightness brightness = Theme.of(this).brightness;
    return Theme.of(this).extension<AppColors>() ??
        (brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}
