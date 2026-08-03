// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/network/loaded.dart';
import '../../../../l10n/l10n.dart';
import '../../../news/application/news_providers.dart';
import '../../../news/application/news_read_controller.dart';
import '../../../news/data/news_models.dart';
import '../../../news/domain/read_state.dart';
import 'dashboard_section.dart';

/// Unread announcements.
///
/// Shows the count and the newest unread headlines. Read state is local, so
/// this card works offline and reports nothing to any backend.
///
/// With nothing unread the card renders **nothing at all** rather than an
/// "all read" panel: a dashboard is for what needs attention, and a card that
/// only ever says "no news" is just a row of wasted screen.
class UnreadNewsCard extends ConsumerWidget {
  const UnreadNewsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<NewsPage>> feed = ref.watch(newsFeedProvider);
    final NewsReadState readState = ref.watch(newsReadProvider);

    return switch (feed) {
      AsyncError<Loaded<NewsPage>>() => DashboardSection(
        title: l10n.navNews,
        icon: Icons.article_outlined,
        onTap: () => GoRouter.of(context).go(AppRoutes.news),
        child: const DashboardCardError(),
      ),
      AsyncData<Loaded<NewsPage>>(:final Loaded<NewsPage> value) => _Unread(
        articles: value.value.articles
            .where((NewsArticle a) => readState.isUnread(a.slug))
            .toList(growable: false),
      ),
      // Nothing to say while it loads — the card appears once there is news.
      _ => const SizedBox.shrink(),
    };
  }
}

class _Unread extends StatelessWidget {
  const _Unread({required this.articles});

  final List<NewsArticle> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;

    return DashboardSection(
      title: l10n.navNews,
      icon: Icons.article_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.news),
      trailing: Text(
        '${articles.length}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DashboardLine(l10n.newsUnreadCount(articles.length)),
          const SizedBox(height: 2),
          for (final NewsArticle article in articles.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                article.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
