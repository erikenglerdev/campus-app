// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/content_blocks_view.dart';
import '../../../l10n/l10n.dart';
import '../application/news_feed_ui_providers.dart';
import '../data/news_models.dart';
import '../domain/article_age.dart';
import '../domain/channel_handle.dart';
import '../domain/news_preview.dart';
import 'news_age_text.dart';

/// One article in the feed — title, channel handles, age and the article itself.
///
/// The card is **not** a button and carries no button semantics. There is no
/// article detail page any more: everything the article says is already here,
/// so a tap on the card would have nowhere to go. Only the real actions — the
/// expand button and the links inside the rich text — are controls.
///
/// The teaser and the authors are deliberately not shown. Both still exist in
/// the CMS and the API for compatibility; the feed shows the article.
class NewsCard extends ConsumerWidget {
  const NewsCard({required this.article, super.key});

  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final AppMetrics metrics = context.metrics;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    final bool expanded = ref.watch(
      newsExpansionProvider.select(
        (Set<String> slugs) => slugs.contains(article.slug),
      ),
    );
    // One clock for the whole feed keeps "vor 3 min" honest while reading,
    // without a timer per card.
    final ArticleAge? age = articleAge(
      article.publishedAt,
      now: ref.watch(newsClockProvider),
    );
    final List<String> handles = channelHandles(
      article.channels.map((NewsChannelRef channel) => channel.name),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The meta line sits above the title rather than beside it, so a
            // long headline and a doubled text size never squeeze each other.
            if (article.isPinned || age != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // The pin wraps rather than pushing the timestamp off the
                    // card at a large text size.
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (article.isPinned)
                            _MetaLabel(
                              icon: Icons.push_pin_outlined,
                              label: l10n.newsPinnedLabel,
                            ),
                        ],
                      ),
                    ),
                    if (age != null)
                      Text(
                        newsAgeText(l10n, locale, age),
                        textAlign: TextAlign.end,
                        style: text.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

            Semantics(
              header: true,
              child: Text(
                article.title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),

            if (handles.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                handles.join(' '),
                style: text.labelMedium?.copyWith(color: colors.primary),
              ),
            ],

            SizedBox(height: metrics.cardGap),
            _ArticleBody(
              article: article,
              expanded: expanded,
              onToggle: () =>
                  ref.read(newsExpansionProvider.notifier).toggle(article.slug),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon plus its word — a state is never carried by the icon alone.
class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconSmall, color: colors.primary),
        const SizedBox(width: AppSpacing.xxs),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.primary),
          ),
        ),
      ],
    );
  }
}

/// The article itself: six lines, or all of it.
class _ArticleBody extends ConsumerWidget {
  const _ArticleBody({
    required this.article,
    required this.expanded,
    required this.onToggle,
  });

  final NewsArticle article;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextStyle style = Theme.of(context).textTheme.bodyLarge!;

    if (article.content.isEmpty) {
      // The teaser is not offered as a substitute — it would look like the
      // article while being something else.
      return Text(
        l10n.newsNoContent,
        style: style.copyWith(color: context.colors.textSecondary),
      );
    }

    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The real rich text: working links, images, everything the preview
          // cannot show.
          ContentBlocksView(blocks: article.content),
          if (article.sourceName != null || article.sourceUrl != null)
            _SourceLink(article: article),
          _ToggleButton(label: l10n.newsShowLess, onPressed: onToggle),
        ],
      );
    }

    final String preview = newsPreviewText(article.content);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Only the layout knows whether six lines were enough, so the question
        // is answered at the width the text actually gets and at the reader's
        // own text size.
        final TextPainter painter = TextPainter(
          text: TextSpan(text: preview, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: kNewsPreviewLines,
        )..layout(maxWidth: constraints.maxWidth);
        final bool overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              preview,
              style: style,
              maxLines: kNewsPreviewLines,
              overflow: TextOverflow.ellipsis,
            ),
            // Offered only when there is genuinely something behind it.
            if (hasMoreToShow(
              blocks: article.content,
              textOverflows: overflows,
            ))
              _ToggleButton(label: l10n.newsShowMore, onPressed: onToggle),
          ],
        );
      },
    );
  }
}

/// The article's attribution and, if there is one, a link to the original.
///
/// Editorial pieces summarise a source rather than copying it, so the way back
/// to that source has to stay reachable now that the card is the whole article.
class _SourceLink extends ConsumerWidget {
  const _SourceLink({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        if (article.sourceName != null)
          Text(
            l10n.newsSourceLabel(article.sourceName!),
            style: text.bodySmall,
          ),
        if (article.sourceUrl != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _open(context, ref, article.sourceUrl!, l10n),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.newsOpenSource),
            ),
          ),
      ],
    );
  }

  Future<void> _open(
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

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(onPressed: onPressed, child: Text(label)),
  );
}
