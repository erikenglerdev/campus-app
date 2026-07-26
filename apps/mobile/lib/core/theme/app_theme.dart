// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

/// Builds the Material 3 themes from the typed tokens in [AppColors].
///
/// The font family is the locally bundled variable font *Manrope*
/// (`assets/fonts/Manrope-Variable.ttf`, SIL OFL 1.1). No font is ever fetched
/// at runtime, therefore the `google_fonts` package is deliberately not used.
abstract final class AppTheme {
  static const String fontFamily = 'Manrope';

  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    final ColorScheme scheme = ColorScheme(
      brightness: colors.brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      secondaryContainer: colors.surfaceVariant,
      onSecondaryContainer: colors.onSurfaceVariant,
      tertiary: colors.success,
      onTertiary: colors.onSuccess,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.surface,
      onErrorContainer: colors.error,
      surface: colors.surface,
      onSurface: colors.onSurface,
      surfaceContainerLowest: colors.background,
      surfaceContainerLow: colors.background,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceVariant,
      surfaceContainerHighest: colors.surfaceVariant,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.outline,
      outlineVariant: colors.outline,
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.surface,
      inversePrimary: colors.primaryDark,
      shadow: const Color(0x33000000),
      scrim: const Color(0x99000000),
    );

    final TextTheme baseText = _textTheme(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      textTheme: baseText,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.outline.withValues(alpha: 0.24)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline.withValues(alpha: 0.24),
        space: AppSpacing.lg,
        thickness: AppSizes.hairline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        minVerticalPadding: AppSpacing.md,
        minTileHeight: AppSizes.minTouchTarget,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? baseText.labelMedium!.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                )
              : baseText.labelMedium!.copyWith(color: colors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? IconThemeData(color: colors.onPrimaryContainer)
              : IconThemeData(color: colors.textSecondary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        side: BorderSide(color: colors.outline.withValues(alpha: 0.32)),
        labelStyle: baseText.labelLarge!.copyWith(
          color: colors.onSurfaceVariant,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: baseText.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: baseText.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
          textStyle: baseText.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceVariant,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: baseText.bodyMedium!.copyWith(color: colors.surface),
        behavior: SnackBarBehavior.floating,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary),
    );
  }

  static TextTheme _textTheme(AppColors colors) {
    TextStyle style(double size, FontWeight weight, {double? height}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: colors.textPrimary,
      );
    }

    return TextTheme(
      displaySmall: style(32, FontWeight.w800, height: 1.2),
      headlineMedium: style(26, FontWeight.w800, height: 1.25),
      headlineSmall: style(22, FontWeight.w700, height: 1.3),
      titleLarge: style(20, FontWeight.w700, height: 1.3),
      titleMedium: style(17, FontWeight.w700, height: 1.35),
      titleSmall: style(15, FontWeight.w600, height: 1.4),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(15, FontWeight.w400, height: 1.5),
      bodySmall: style(
        13,
        FontWeight.w400,
        height: 1.45,
      ).copyWith(color: colors.textSecondary),
      labelLarge: style(15, FontWeight.w600, height: 1.3),
      labelMedium: style(13, FontWeight.w600, height: 1.3),
      labelSmall: style(12, FontWeight.w600, height: 1.3),
    );
  }
}
