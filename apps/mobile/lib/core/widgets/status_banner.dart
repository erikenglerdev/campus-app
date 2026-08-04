// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Severity of a [StatusBanner].
enum StatusTone { info, warning, positive }

/// An inline status hint.
///
/// The banner always sits on `surface` — that is the pairing the contrast test
/// asserts — and always combines an icon **and** text with its accent colour,
/// so no state is communicated through colour alone.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.title,
    this.message,
    this.tone = StatusTone.info,
    this.icon,
    super.key,
  });

  final String title;
  final String? message;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = switch (tone) {
      StatusTone.info => colors.primary,
      StatusTone.warning => colors.error,
      StatusTone.positive => colors.success,
    };
    final IconData effectiveIcon =
        icon ??
        switch (tone) {
          StatusTone.info => Icons.info_outline,
          StatusTone.warning => Icons.warning_amber_outlined,
          StatusTone.positive => Icons.check_circle_outline,
        };

    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border(
            left: BorderSide(color: accent, width: AppSizes.statusBar),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(effectiveIcon, color: accent, size: AppSizes.icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Sized by its text, never by the space around it. In a
                  // scrolling list the height is unbounded and the default
                  // `max` happens to hug the children anyway — but inside a
                  // box that has a height, a centred empty state for example,
                  // the banner stretched to fill all of it.
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        message!,
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
