// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/seen_detector.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/channel_subscriptions.dart';
import '../application/news_feed_controller.dart';
import '../application/news_providers.dart';
import '../application/news_read_controller.dart';
import '../data/news_models.dart';
import '../domain/read_state.dart';
import 'news_card.dart';
import 'news_filter_sheet.dart';

/// The news feed: a centred title, one filter button and an endless list of
/// articles that are read in place.
///
/// There is no article detail page. The list endpoint delivers the sanitised
/// content of every article, so a card expands inline instead of navigating —
/// which also means the feed never makes one request per visible card.
class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  @override
  void initState() {
    super.initState();
    // A feed that was already loaded when this screen opened produces no
    // change for the listener below to see.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NewsFeedState? state = ref.read(newsFeedControllerProvider).value;
      if (state != null) _syncReadState(state);
    });
  }

  /// Reconciles the local read markers with what the feed currently holds.
  ///
  /// Pruning is only allowed once the **whole** feed has been loaded: doing it
  /// against the pages seen so far would drop the marker of every article
  /// further down and make the archive unread again.
  void _syncReadState(NewsFeedState state) {
    ref
        .read(newsReadProvider.notifier)
        .syncWithFeed(
          state.articles.map((NewsArticle article) => article.slug),
          complete: !state.hasMore,
        );
  }

  Future<void> _refresh() async {
    ref.invalidate(newsChannelsProvider);
    await ref.read(newsFeedControllerProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NewsFeedState> feed = ref.watch(
      newsFeedControllerProvider,
    );

    ref.listen<AsyncValue<NewsFeedState>>(newsFeedControllerProvider, (
      AsyncValue<NewsFeedState>? _,
      AsyncValue<NewsFeedState> next,
    ) {
      final NewsFeedState? state = next.value;
      if (state != null) _syncReadState(state);
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _FeedHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: switch (feed) {
                  AsyncLoading<NewsFeedState>() when !feed.hasValue =>
                    const LoadingView(),
                  AsyncError<NewsFeedState>(:final Object error) =>
                    scrollableState(
                      child: ErrorView(
                        failure: error,
                        onRetry: () {
                          ref.invalidate(newsChannelsProvider);
                          ref.invalidate(newsFeedControllerProvider);
                        },
                      ),
                    ),
                  _ => _FeedBody(state: feed.requireValue),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty and error states must stay pull-to-refreshable.
///
/// Uses [SliverFillRemaining] rather than a `SingleChildScrollView` with a
/// `ConstrainedBox(minHeight:)`: that combination leaves the child's height
/// unbounded, so a centred state could not use `Expanded` and threw a layout
/// assertion. `hasScrollBody: false` hands the child a BOUNDED height equal to
/// the remaining viewport, which is exactly what a centred empty state needs,
/// while the scroll view keeps pull-to-refresh working.
Widget scrollableState({required Widget child, Widget? header}) {
  return CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: <Widget>[
      if (header != null) SliverToBoxAdapter(child: header),
      SliverFillRemaining(hasScrollBody: false, child: child),
    ],
  );
}

/// The centred feed title and the single filter button.
class _FeedHeader extends ConsumerWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;

    final bool unreadOnly = ref.watch(newsUnreadOnlyProvider);
    final List<NewsChannel> channels =
        ref.watch(newsChannelsProvider).value?.value ?? const <NewsChannel>[];
    final ChannelSubscriptionState subscriptions = ref.watch(
      channelSubscriptionProvider,
    );
    // "Some channels are switched off" is a filter the reader should be able to
    // see from the outside — otherwise a missing article looks like a bug.
    final bool filtered =
        unreadOnly ||
        (channels.isNotEmpty &&
            subscriptions.selectedSlugs.length < channels.length);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          // Balances the button on the right so the title is genuinely centred.
          const SizedBox(width: AppSizes.minTouchTarget),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.newsFeedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.newsFilterTooltip,
            onPressed: () => showNewsFilterSheet(context),
            // A different icon, not just a different colour.
            isSelected: filtered,
            icon: const Icon(Icons.filter_alt_outlined),
            selectedIcon: const Icon(Icons.filter_alt),
          ),
        ],
      ),
    );
  }
}

/// What the feed has to say about itself before the first article.
///
/// Both notices are about the response as a whole, not about one card: the
/// content is from the offline cache, or it is shown in German because no
/// translation exists.
List<Widget> _notices(BuildContext context, NewsFeedState state) => <Widget>[
  if (state.fromCache) OfflineNotice(cachedAt: state.cachedAt),
  if (state.translationFallback)
    StatusBanner(
      icon: Icons.translate_outlined,
      title: context.l10n.newsTranslationFallbackHint,
    ),
];

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.state});

  final NewsFeedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppMetrics metrics = context.metrics;
    final NewsReadState readState = ref.watch(newsReadProvider);
    final bool unreadOnly = ref.watch(newsUnreadOnlyProvider);

    final List<NewsArticle> all = state.articles;
    final List<NewsArticle> articles = unreadOnly
        ? all
              .where((NewsArticle a) => readState.isUnread(a.slug))
              .toList(growable: false)
        : all;

    if (articles.isEmpty) {
      return _EmptyFeed(
        state: state,
        unreadOnly: unreadOnly,
        hadAny: all.isNotEmpty,
      );
    }

    final List<Widget> notices = _notices(context, state);
    final bool showFooter = state.hasMore || state.loadMoreFailed;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(metrics.screenPadding),
      itemCount: notices.length + articles.length + (showFooter ? 1 : 0),
      separatorBuilder: (BuildContext _, int _) =>
          SizedBox(height: metrics.cardGap),
      itemBuilder: (BuildContext context, int index) {
        if (index < notices.length) return notices[index];
        final int articleIndex = index - notices.length;
        if (articleIndex >= articles.length) {
          return _LoadMoreFooter(state: state);
        }

        final NewsArticle article = articles[articleIndex];
        final bool isUnread = readState.isUnread(article.slug);
        final Widget card = NewsCard(
          key: ValueKey<String>(article.slug),
          article: article,
          isUnread: isUnread,
          onExpanded: (String slug) =>
              ref.read(newsReadProvider.notifier).markRead(slug),
        );

        // Reading an article marks it read — but not while the unread filter is
        // on, where it would vanish from under the reader's finger.
        if (!isUnread || unreadOnly) return card;
        return SeenDetector(
          onSeen: () =>
              ref.read(newsReadProvider.notifier).markRead(article.slug),
          child: card,
        );
      },
    );
  }
}

/// Why the feed is empty — the answers are genuinely different.
class _EmptyFeed extends ConsumerWidget {
  const _EmptyFeed({
    required this.state,
    required this.unreadOnly,
    required this.hadAny,
  });

  final NewsFeedState state;
  final bool unreadOnly;

  /// Whether the feed itself holds articles and only the filter hides them.
  final bool hadAny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<NewsChannel> channels =
        ref.watch(newsChannelsProvider).value?.value ?? const <NewsChannel>[];
    final ChannelSubscriptionState subscriptions = ref.watch(
      channelSubscriptionProvider,
    );

    // "Nothing unread" is a different answer from "no announcements at all",
    // and the filter is the thing to undo — so it gets its own empty state.
    if (unreadOnly && hadAny) {
      return scrollableState(
        child: EmptyView(
          icon: Icons.mark_email_read_outlined,
          title: l10n.newsAllRead,
          message: l10n.newsNoUnread,
          action: FilledButton.icon(
            onPressed: () => ref.read(newsUnreadOnlyProvider.notifier).toggle(),
            icon: const Icon(Icons.list),
            label: Text(l10n.newsShowAll),
          ),
        ),
      );
    }

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
          onPressed: () => showNewsFilterSheet(context),
          icon: const Icon(Icons.filter_alt_outlined),
          label: Text(l10n.newsChannelPickerTitle),
        ),
      );
    } else {
      empty = EmptyView(
        title: l10n.newsEmptyTitle,
        message: l10n.newsEmptyMessage,
      );
    }

    final List<Widget> notices = _notices(context, state);
    return scrollableState(
      header: notices.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(mainAxisSize: MainAxisSize.min, children: notices),
            ),
      child: empty,
    );
  }
}

/// The end of the list: loads the next page, or explains why it could not.
///
/// Requesting the page here rather than from a scroll offset is what makes the
/// feed load *shortly before* the end: the list builds its items a little ahead
/// of the viewport, so this footer exists before the reader reaches it.
class _LoadMoreFooter extends ConsumerStatefulWidget {
  const _LoadMoreFooter({required this.state});

  final NewsFeedState state;

  @override
  ConsumerState<_LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends ConsumerState<_LoadMoreFooter> {
  /// The page this footer has already asked to follow.
  ///
  /// Without it a rebuild during the request would queue a second one.
  int? _requested;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _LoadMoreFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoad();
  }

  void _maybeLoad() {
    final NewsFeedState state = widget.state;
    if (!state.hasMore || state.isLoadingMore) return;
    // A failed page waits for the reader to press retry. Retrying by itself
    // would hammer an endpoint that has just said no.
    if (state.loadMoreFailed || _requested == state.page) return;
    _requested = state.page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(newsFeedControllerProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (widget.state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: <Widget>[
            Text(
              l10n.newsLoadMoreFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () {
                _requested = null;
                ref.read(newsFeedControllerProvider.notifier).loadMore();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.newsLoadMoreRetry),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
