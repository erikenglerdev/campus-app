// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/accent_palette.dart';
import '../../../core/theme/app_density.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';

/// Localised name of an accent palette.
///
/// Lives next to the settings UI rather than on the enum: the palette is a
/// design token, and only this screen ever needs to name it.
String accentPaletteLabel(AppLocalizations l10n, AccentPalette palette) =>
    switch (palette) {
      AccentPalette.campusViolet => l10n.settingsAccentCampusViolet,
      AccentPalette.oceanBlue => l10n.settingsAccentOceanBlue,
      AccentPalette.deepTeal => l10n.settingsAccentDeepTeal,
      AccentPalette.freshGreen => l10n.settingsAccentFreshGreen,
      AccentPalette.brightMagenta => l10n.settingsAccentBrightMagenta,
      AccentPalette.warmAmber => l10n.settingsAccentWarmAmber,
    };

/// The accent picker: a row of swatches, each also carrying its name.
///
/// A swatch alone would make the choice colour-only, which is exactly what the
/// project rules forbid — so the selected one is marked with a check **and**
/// named underneath the row.
class AccentColorTile extends ConsumerWidget {
  const AccentColorTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AccentPalette current = ref.watch(
      settingsProvider.select((AppSettings s) => s.accentPalette),
    );
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.settingsAccentColor,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final AccentPalette palette in AccentPalette.values)
                _Swatch(
                  palette: palette,
                  colour: isDark ? palette.dark.primary : palette.light.primary,
                  onColour: isDark
                      ? palette.dark.onPrimary
                      : palette.light.onPrimary,
                  selected: palette == current,
                  label: accentPaletteLabel(l10n, palette),
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .setAccentPalette(palette),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // The current choice in words, so the state is never colour-only.
          Text(
            accentPaletteLabel(l10n, current),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.colour,
    required this.onColour,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AccentPalette palette;
  final Color colour;
  final Color onColour;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colour,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: AppSizes.iconSmall, color: onColour)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Comfortable or compact. Two named steps, never a slider — see
/// [DisplayDensity].
class DensityTile extends ConsumerWidget {
  const DensityTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DisplayDensity current = ref.watch(
      settingsProvider.select((AppSettings s) => s.displayDensity),
    );

    String label(DisplayDensity density) => switch (density) {
      DisplayDensity.comfortable => l10n.settingsDensityComfortable,
      DisplayDensity.compact => l10n.settingsDensityCompact,
    };

    // Radio rows rather than a trailing dropdown: a dropdown's label sits in
    // the row's trailing slot, and at large text scales it pushes the row past
    // the edge of a 320 px phone. This also matches how language and theme are
    // presented two rows above.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            l10n.settingsDensity,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        RadioGroup<DisplayDensity>(
          groupValue: current,
          onChanged: (DisplayDensity? density) {
            if (density == null) return;
            ref.read(settingsProvider.notifier).setDisplayDensity(density);
          },
          child: Column(
            children: <Widget>[
              for (final DisplayDensity density in DisplayDensity.values)
                RadioListTile<DisplayDensity>.adaptive(
                  value: density,
                  title: Text(label(density)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The local reduced-motion switch.
///
/// Its subtitle says outright that the system setting applies anyway, so
/// leaving this off is not mistaken for "animate regardless".
class ReducedMotionTile extends ConsumerWidget {
  const ReducedMotionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = ref.watch(
      settingsProvider.select((AppSettings s) => s.reducedMotion),
    );

    return SwitchListTile(
      secondary: const Icon(Icons.motion_photos_off_outlined),
      title: Text(l10n.settingsReducedMotion),
      subtitle: Text(l10n.settingsReducedMotionSubtitle),
      value: enabled,
      onChanged: (bool value) =>
          ref.read(settingsProvider.notifier).setReducedMotion(value),
    );
  }
}
