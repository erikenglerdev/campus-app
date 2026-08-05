// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/theme/accent_palette.dart';
import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/app_metrics.dart';
import 'package:campus_koethen/core/theme/app_dimensions.dart';
import 'package:campus_koethen/core/theme/app_motion.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout metrics', () {
    test('the one metric set never goes below the minimum touch target', () {
      // The app no longer offers a density choice; the single set it does use
      // still has to keep every row tappable.
      expect(
        AppMetrics.standard.listRowMinHeight,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
    });

    test('spacing is positive and ordered', () {
      const AppMetrics m = AppMetrics.standard;
      expect(m.screenPadding, greaterThan(0));
      expect(m.cardGap, greaterThan(0));
      expect(m.sectionGap, greaterThan(m.cardGap));
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
      AppMotion motion = AppMotion.enabled,
    }) => AppTheme.light(accent: accent, motion: motion);

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

    test('the metrics reach the list theme', () {
      final ThemeData theme = themed();
      expect(
        theme.listTileTheme.minTileHeight,
        AppMetrics.standard.listRowMinHeight,
      );
      expect(
        theme.listTileTheme.minTileHeight,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
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
