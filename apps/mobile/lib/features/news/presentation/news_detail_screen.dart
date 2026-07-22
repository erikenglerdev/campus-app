// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/content_blocks_view.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/news_providers.dart';
import '../data/news_models.dart';

/// Renders one article. Only the block types of the API contract are drawn.
class NewsDetailScreen extends ConsumerWidget {
  const NewsDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<NewsArticle>> article = ref.watch(
      newsArticleProvider(slug),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newsTitle)),
      body: switch (article) {
        AsyncLoading<Loaded<NewsArticle>>() when !article.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<NewsArticle>>(:final Object error) => ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(newsArticleProvider(slug)),
        ),
        _ => _ArticleBody(loaded: article.requireValue),
      },
    );
  }
}

class _ArticleBody extends ConsumerWidget {
  const _ArticleBody({required this.loaded});

  final Loaded<NewsArticle> loaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;
    final NewsArticle article = loaded.value;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        if (loaded.fromCache) ...<Widget>[
          OfflineNotice(cachedAt: loaded.cachedAt),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (loaded.meta.translationFallback) ...<Widget>[
          StatusBanner(
            icon: Icons.translate_outlined,
            title: l10n.newsTranslationFallbackHint,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (article.heroImage != null) ...<Widget>[
          RemoteImage(
            url: article.heroImage!.url,
            alternativeText: article.heroImage!.alternativeText,
            aspectRatio: article.heroImage!.aspectRatio,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Semantics(
          header: true,
          child: Text(article.title, style: text.headlineSmall),
        ),
        if (article.publishedAt != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.newsPublishedAt(
              AppDateFormats.longDate(article.publishedAt!, locale),
            ),
            style: text.bodySmall,
          ),
        ],
        if (article.authors.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.newsAuthorsLabel(
              article.authors
                  .map((NewsAuthor author) => author.name)
                  .join(', '),
            ),
            style: text.bodySmall,
          ),
        ],
        if (article.teaser != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(article.teaser!, style: text.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        ContentBlocksView(blocks: article.content),
        if (article.sourceName != null || article.sourceUrl != null) ...<Widget>[
          const Divider(),
          if (article.sourceName != null)
            Text(l10n.newsSourceLabel(article.sourceName!), style: text.bodySmall),
          if (article.sourceUrl != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    _openSource(context, ref, article.sourceUrl!, l10n),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.newsOpenSource),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _openSource(
    BuildContext context,
    WidgetRef ref,
    String url,
    AppLocalizations l10n,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (result == LinkLaunchResult.opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == LinkLaunchResult.blocked
              ? l10n.errorLinkBlocked
              : l10n.errorLinkNotOpened,
        ),
      ),
    );
  }
}
