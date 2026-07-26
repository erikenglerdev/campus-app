// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../data/news_models.dart';

/// A single article in the news list.
///
/// Pinned articles are marked with an icon **and** a text label — never with
/// colour alone.
class NewsCard extends StatelessWidget {
  const NewsCard({required this.article, required this.onTap, super.key});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime? publishedAt = article.publishedAt;

    final String semanticLabel = publishedAt == null
        ? article.title
        : l10n.newsArticleSemanticLabel(
            article.title,
            AppDateFormats.longDate(publishedAt, locale),
          );

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (article.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.push_pin_outlined,
                            size: AppSpacing.lg,
                            color: colors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            l10n.newsPinnedLabel,
                            style: text.labelMedium?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(article.title, style: text.titleMedium),
                  if (article.teaser != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      article.teaser!,
                      style: text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  if (publishedAt != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.newsPublishedAt(
                        AppDateFormats.longDate(publishedAt, locale),
                      ),
                      style: text.bodySmall,
                    ),
                  ],
                  if (article.channels.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final NewsChannelRef channel in article.channels)
                          Chip(
                            label: Text(channel.name),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
