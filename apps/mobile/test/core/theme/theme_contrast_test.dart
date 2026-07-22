// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A foreground/background pairing the app actually renders.
class _Pair {
  const _Pair(this.name, this.foreground, this.background, this.threshold);

  final String name;
  final Color foreground;
  final Color background;
  final double threshold;
}

List<_Pair> _pairsFor(AppColors c) => <_Pair>[
  // Body copy.
  _Pair('textPrimary on background', c.textPrimary, c.background, Contrast.aaBody),
  _Pair('textPrimary on surface', c.textPrimary, c.surface, Contrast.aaBody),
  _Pair(
    'textSecondary on background',
    c.textSecondary,
    c.background,
    Contrast.aaBody,
  ),
  _Pair('textSecondary on surface', c.textSecondary, c.surface, Contrast.aaBody),
  _Pair(
    'onSurfaceVariant on surfaceVariant',
    c.onSurfaceVariant,
    c.surfaceVariant,
    Contrast.aaBody,
  ),

  // Brand colour as text / icon colour. Only ever used on `surface`, which is
  // why status banners are surface coloured.
  _Pair('primary on surface', c.primary, c.surface, Contrast.aaBody),
  _Pair('primary on background', c.primary, c.background, Contrast.aaBody),
  _Pair(
    'onPrimaryContainer on primaryContainer',
    c.onPrimaryContainer,
    c.primaryContainer,
    Contrast.aaBody,
  ),

  // Filled controls.
  _Pair('onPrimary on primary', c.onPrimary, c.primary, Contrast.aaBody),
  _Pair('onAccent on accent', c.onAccent, c.accent, Contrast.aaBody),
  _Pair('onSuccess on success', c.onSuccess, c.success, Contrast.aaBody),
  _Pair('onError on error', c.onError, c.error, Contrast.aaBody),

  // Semantic accents. These are rendered as icon + text on `surface` only.
  _Pair('success on surface', c.success, c.surface, Contrast.aaBody),
  _Pair('error on surface', c.error, c.surface, Contrast.aaBody),

  // Non-text UI: hairlines and focus rings only need 3:1.
  _Pair('outline on surface', c.outline, c.surface, Contrast.aaLarge),
  _Pair('outline on background', c.outline, c.background, Contrast.aaLarge),
];

void main() {
  group('Contrast helper', () {
    test('matches the WCAG reference values', () {
      expect(
        Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        Contrast.ratio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1, 0.001),
      );
      // Known reference pair: #767676 on white is exactly at the AA threshold.
      expect(
        Contrast.ratio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        greaterThanOrEqualTo(Contrast.aaBody),
      );
    });

    test('is symmetric', () {
      const Color a = Color(0xFF5B3FD0);
      const Color b = Color(0xFFF7F5F2);
      expect(Contrast.ratio(a, b), closeTo(Contrast.ratio(b, a), 1e-12));
    });
  });

  group('light theme', () {
    for (final _Pair pair in _pairsFor(AppColors.light)) {
      test('${pair.name} meets ${pair.threshold}:1', () {
        final double ratio = Contrast.ratio(pair.foreground, pair.background);
        expect(
          ratio,
          greaterThanOrEqualTo(pair.threshold),
          reason:
              '${pair.name} is ${ratio.toStringAsFixed(2)}:1, '
              'required ${pair.threshold}:1',
        );
      });
    }
  });

  group('dark theme', () {
    for (final _Pair pair in _pairsFor(AppColors.dark)) {
      test('${pair.name} meets ${pair.threshold}:1', () {
        final double ratio = Contrast.ratio(pair.foreground, pair.background);
        expect(
          ratio,
          greaterThanOrEqualTo(pair.threshold),
          reason:
              '${pair.name} is ${ratio.toStringAsFixed(2)}:1, '
              'required ${pair.threshold}:1',
        );
      });
    }

    test('uses genuinely dark surfaces', () {
      expect(
        Contrast.relativeLuminance(AppColors.dark.background),
        lessThan(0.05),
      );
      expect(Contrast.relativeLuminance(AppColors.dark.surface), lessThan(0.06));
      expect(
        Contrast.relativeLuminance(AppColors.dark.surface),
        greaterThan(Contrast.relativeLuminance(AppColors.dark.background)),
        reason: 'elevation is expressed by lighter surfaces',
      );
    });
  });
}
