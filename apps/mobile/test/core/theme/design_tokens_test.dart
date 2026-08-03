// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/theme/accent_palette.dart';
import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/app_density.dart';
import 'package:campus_koethen/core/theme/app_dimensions.dart';
import 'package:campus_koethen/core/theme/app_motion.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('display density', () {
    test('an unknown stored value falls back to comfortable', () {
      expect(DisplayDensity.fromStorage(null), DisplayDensity.comfortable);
      expect(DisplayDensity.fromStorage('cosy'), DisplayDensity.comfortable);
      expect(DisplayDensity.fromStorage('compact'), DisplayDensity.compact);
    });

    test('compact is genuinely tighter than comfortable', () {
      expect(
        AppMetrics.compact.screenPadding,
        lessThan(AppMetrics.comfortable.screenPadding),
      );
      expect(
        AppMetrics.compact.cardGap,
        lessThan(AppMetrics.comfortable.cardGap),
      );
      expect(
        AppMetrics.compact.sectionGap,
        lessThan(AppMetrics.comfortable.sectionGap),
      );
    });

    test('compact never goes below the minimum touch target', () {
      // This is the whole reason density is two named steps and not a slider.
      for (final AppMetrics metrics in <AppMetrics>[
        AppMetrics.comfortable,
        AppMetrics.compact,
      ]) {
        expect(
          metrics.listRowMinHeight,
          greaterThanOrEqualTo(AppSizes.minTouchTarget),
          reason: '${metrics.density.storageValue} rows must stay tappable',
        );
      }
    });
  });

  group('motion', () {
    test('either source alone switches reduced motion on', () {
      expect(
        AppMotion.resolve(
          systemDisablesAnimations: true,
          userPrefersReducedMotion: false,
        ).reduced,
        isTrue,
        reason: 'the operating system setting must be honoured on its own',
      );
      expect(
        AppMotion.resolve(
          systemDisablesAnimations: false,
          userPrefersReducedMotion: true,
        ).reduced,
        isTrue,
        reason: 'the in-app toggle must be honoured on its own',
      );
      expect(
        AppMotion.resolve(
          systemDisablesAnimations: false,
          userPrefersReducedMotion: false,
        ).reduced,
        isFalse,
      );
    });

    test('reduced motion means no motion, not fast motion', () {
      expect(AppMotion.suppressed.fast, Duration.zero);
      expect(AppMotion.suppressed.medium, Duration.zero);
      expect(AppMotion.suppressed.slow, Duration.zero);
    });

    test('motion tokens do not interpolate across a theme change', () {
      // Crossing from animated to reduced has to take effect at once.
      final AppMotion mid = AppMotion.enabled.lerp(AppMotion.suppressed, 0.6);
      expect(mid.reduced, isTrue);
      expect(mid.fast, Duration.zero);
    });
  });

  group('theme assembly', () {
    ThemeData themed({
      AccentPalette accent = AccentPalette.fallback,
      DisplayDensity density = DisplayDensity.fallback,
      AppMotion motion = AppMotion.enabled,
    }) => AppTheme.light(accent: accent, density: density, motion: motion);

    test('carries colours, metrics and motion as typed extensions', () {
      final ThemeData theme = themed();
      expect(theme.extension<AppColors>(), isNotNull);
      expect(theme.extension<AppMetrics>(), isNotNull);
      expect(theme.extension<AppMotion>(), isNotNull);
    });

    test('the chosen accent reaches the colour scheme', () {
      final ThemeData teal = themed(accent: AccentPalette.deepTeal);
      expect(
        teal.colorScheme.primary,
        AccentPalette.deepTeal.light.primary,
        reason: 'a palette must not stop at the extension',
      );
      expect(
        teal.extension<AppColors>()!.primary,
        AccentPalette.deepTeal.light.primary,
      );
    });

    test('density reaches the list and navigation themes', () {
      final ThemeData compact = themed(density: DisplayDensity.compact);
      final ThemeData comfortable = themed();
      expect(
        compact.listTileTheme.minTileHeight,
        lessThan(comfortable.listTileTheme.minTileHeight!),
      );
      expect(
        compact.listTileTheme.minTileHeight,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
      expect(
        compact.navigationBarTheme.height,
        lessThan(comfortable.navigationBarTheme.height!),
      );
    });

    test('reduced motion removes the platform page transition', () {
      final ThemeData reduced = themed(motion: AppMotion.suppressed);
      final ThemeData normal = themed();
      // Same route, same child: with reduced motion the builder must hand the
      // child back untouched instead of wrapping it in a transition.
      expect(
        reduced.pageTransitionsTheme.builders[TargetPlatform.android],
        isNot(
          equals(normal.pageTransitionsTheme.builders[TargetPlatform.android]),
        ),
      );
      expect(reduced.extension<AppMotion>()!.reduced, isTrue);
    });

    test('dark keeps genuinely dark surfaces under every accent', () {
      for (final AccentPalette accent in AccentPalette.values) {
        final AppColors colors = AppTheme.dark(
          accent: accent,
        ).extension<AppColors>()!;
        expect(colors.brightness, Brightness.dark);
        expect(colors.background, AppColors.dark.background);
      }
    });
  });
}
