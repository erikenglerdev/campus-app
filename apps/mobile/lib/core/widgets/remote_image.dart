// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Displays an editorial image from an `https` URL.
///
/// A failing image is *not* an error state: it collapses to nothing so a
/// broken asset can never block an article. There are deliberately no canteen
/// images anywhere in this app.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    required this.url,
    this.alternativeText,
    this.aspectRatio,
    super.key,
  });

  final String url;
  final String? alternativeText;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Widget image = Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      semanticLabel: alternativeText,
      errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
          const SizedBox.shrink(),
      loadingBuilder:
          (BuildContext _, Widget child, ImageChunkEvent? progress) =>
              progress == null
              ? child
              : ColoredBox(
                  color: colors.surfaceVariant,
                  child: const SizedBox(height: AppSpacing.xxxl),
                ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: aspectRatio == null
          ? image
          : AspectRatio(aspectRatio: aspectRatio!, child: image),
    );
  }
}
