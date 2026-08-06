// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../network/api_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Displays an editorial image the Campus API published.
///
/// [url] is whatever the API delivered — normally an API-relative media path
/// (`/v1/media/…`). Resolving it happens **here** rather than at every call
/// site, so no screen can forget it and none of them has to know where the
/// images live.
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
    final String? resolved = ApiConfig.resolveMediaUrl(url);
    // An unusable reference is nothing to apologise for — the layout simply
    // does without the picture.
    if (resolved == null) return const SizedBox.shrink();

    final Widget image = Image.network(
      resolved,
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
