// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/channel_subscriptions.dart';
import '../application/news_providers.dart';
import '../data/news_models.dart';
import 'channel_picker_sheet.dart';
import 'news_card.dart';

/// The news list: pull to refresh, loading, error with retry and two distinct
/// empty states (no channels at all vs. no channel selected).
class NewsListScreen extends ConsumerWidget {
  const NewsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<NewsPage>> feed = ref.watch(newsFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.newsChannelPickerTooltip,
            onPressed: () => showChannelPickerSheet(context),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(newsChannelsProvider);
          await ref.read(newsFeedProvider.future);
        },
        child: switch (feed) {
          AsyncLoading<Loaded<NewsPage>>() when !feed.hasValue =>
            const LoadingView(),
          AsyncError<Loaded<NewsPage>>(:final Object error) => _scrollable(
            child: ErrorView(
              failure: error,
              onRetry: () {
                ref.invalidate(newsChannelsProvider);
                ref.invalidate(newsFeedProvider);
              },
            ),
          ),
          _ => _NewsListBody(loaded: feed.requireValue),
        },
      ),
    );
  }

  /// Empty and error states must stay pull-to-refreshable.
  ///
  /// Uses [SliverFillRemaining] rather than a `SingleChildScrollView` with a
  /// `ConstrainedBox(minHeight:)`: that combination leaves the child's height
  /// unbounded, so a centred state could not use `Expanded` and threw a layout
  /// assertion. `hasScrollBody: false` hands the child a BOUNDED height equal
  /// to the remaining viewport, which is exactly what a centred empty state
  /// needs, while the scroll view keeps pull-to-refresh working.
  static Widget _scrollable({required Widget child, Widget? header}) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        if (header != null) SliverToBoxAdapter(child: header),
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}

class _NewsListBody extends ConsumerWidget {
  const _NewsListBody({required this.loaded});

  final Loaded<NewsPage> loaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<NewsChannel> channels =
        ref.watch(newsChannelsProvider).value?.value ?? const <NewsChannel>[];
    final ChannelSubscriptionState subscriptions = ref.watch(
      channelSubscriptionProvider,
    );
    final List<NewsArticle> articles = loaded.value.articles;

    if (articles.isEmpty) {
      final Widget empty;
      if (channels.isEmpty) {
        empty = EmptyView(
          icon: Icons.rss_feed_outlined,
          title: l10n.newsNoChannelsAvailableTitle,
          message: l10n.newsNoChannelsAvailableMessage,
        );
      } else if (subscriptions.selectedSlugs.isEmpty) {
        empty = EmptyView(
          icon: Icons.filter_list_off,
          title: l10n.newsNoChannelsSelectedTitle,
          message: l10n.newsNoChannelsSelectedMessage,
          action: FilledButton.icon(
            onPressed: () => showChannelPickerSheet(context),
            icon: const Icon(Icons.filter_list),
            label: Text(l10n.newsChannelPickerTitle),
          ),
        );
      } else {
        empty = EmptyView(
          title: l10n.newsEmptyTitle,
          message: l10n.newsEmptyMessage,
        );
      }
      return NewsListScreen._scrollable(
        header: loaded.fromCache
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: OfflineNotice(cachedAt: loaded.cachedAt),
              )
            : null,
        child: empty,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: articles.length + (loaded.fromCache ? 1 : 0),
      separatorBuilder: (BuildContext _, int _) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        if (loaded.fromCache && index == 0) {
          return OfflineNotice(cachedAt: loaded.cachedAt);
        }
        final NewsArticle article =
            articles[loaded.fromCache ? index - 1 : index];
        return NewsCard(
          article: article,
          onTap: () => context.pushNamed(
            AppRoutes.newsDetailName,
            pathParameters: <String, String>{'slug': article.slug},
          ),
        );
      },
    );
  }
}
