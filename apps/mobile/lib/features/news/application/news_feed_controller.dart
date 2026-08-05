// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'channel_subscriptions.dart';
import 'news_providers.dart';

/// Everything the feed screen needs to draw itself.
@immutable
class NewsFeedState {
  const NewsFeedState({
    required this.articles,
    required this.page,
    required this.totalPages,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.fromCache = false,
    this.cachedAt,
  });

  /// Every article loaded so far, in server order, without repeats.
  final List<NewsArticle> articles;

  /// The highest page that has been merged in.
  final int page;
  final int totalPages;

  final bool isLoadingMore;

  /// The last attempt to append a page failed.
  ///
  /// A flag rather than the error object: the footer offers a retry, and the
  /// exact upstream failure is not something to put in front of a reader.
  final bool loadMoreFailed;

  /// The first page came from the offline cache.
  final bool fromCache;
  final DateTime? cachedAt;

  bool get hasMore => page < totalPages;

  NewsFeedState copyWith({
    List<NewsArticle>? articles,
    int? page,
    int? totalPages,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => NewsFeedState(
    articles: articles ?? this.articles,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    fromCache: fromCache,
    cachedAt: cachedAt,
  );
}

/// The endlessly scrolling feed.
///
/// Pages are appended, never replaced, and merged by **slug**: the server sorts
/// pinned articles first, so an article pinned between two requests can appear
/// on two pages, and a feed that showed it twice would look broken.
///
/// A failed page does **not** discard what is already on screen. Losing a
/// screenful of articles because the next request timed out is a far worse
/// outcome than a retry button at the bottom.
///
/// The channel selection and the locale are watched, so changing either
/// rebuilds this notifier and the feed starts again at page one — which is the
/// required behaviour and costs no extra code.
class NewsFeedController extends AsyncNotifier<NewsFeedState> {
  NewsRepository get _repository => ref.read(newsRepositoryProvider);

  String? _channelsParameter = '';
  String _locale = 'de';

  @override
  Future<NewsFeedState> build() async {
    _locale = ref.watch(localeCodeProvider);
    final Loaded<List<NewsChannel>> channels = await ref.watch(
      newsChannelsProvider.future,
    );
    final ChannelSubscriptionState subscriptions = ref.watch(
      channelSubscriptionProvider,
    );

    if (channels.value.isEmpty) {
      _channelsParameter = '';
      return const NewsFeedState(
        articles: <NewsArticle>[],
        page: 1,
        totalPages: 1,
      );
    }

    _channelsParameter = ChannelSubscriptionRules.queryValue(
      available: channels.value,
      selected: subscriptions.selectedSlugs,
    );

    final Loaded<NewsPage> first = await _repository.fetchArticles(
      locale: _locale,
      channelsParameter: _channelsParameter,
    );

    return NewsFeedState(
      articles: List<NewsArticle>.unmodifiable(first.value.articles),
      page: first.value.page,
      totalPages: first.value.totalPages,
      fromCache: first.fromCache,
      cachedAt: first.cachedAt,
    );
  }

  /// Appends the next page.
  ///
  /// Does nothing while one is already in flight or when the last page has been
  /// reached, so scrolling near the end cannot fire a burst of requests.
  Future<void> loadMore() async {
    final NewsFeedState? current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData<NewsFeedState>(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );

    try {
      final Loaded<NewsPage> next = await _repository.fetchArticles(
        locale: _locale,
        channelsParameter: _channelsParameter,
        page: current.page + 1,
      );
      // The state may have been replaced while the request was in flight.
      final NewsFeedState base = state.value ?? current;
      state = AsyncData<NewsFeedState>(
        base.copyWith(
          articles: _merge(base.articles, next.value.articles),
          page: next.value.page,
          totalPages: next.value.totalPages,
          isLoadingMore: false,
          loadMoreFailed: false,
        ),
      );
    } on Object {
      final NewsFeedState base = state.value ?? current;
      // Everything already loaded stays. Only the footer changes.
      state = AsyncData<NewsFeedState>(
        base.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }

  /// Pull-to-refresh: back to page one for the current selection.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Appends what is genuinely new, keeping the order of both pages.
  static List<NewsArticle> _merge(
    List<NewsArticle> existing,
    List<NewsArticle> incoming,
  ) {
    final Set<String> seen = existing.map((NewsArticle a) => a.slug).toSet();
    final List<NewsArticle> merged = List<NewsArticle>.of(existing);
    for (final NewsArticle article in incoming) {
      if (seen.add(article.slug)) merged.add(article);
    }
    return List<NewsArticle>.unmodifiable(merged);
  }
}

final AsyncNotifierProvider<NewsFeedController, NewsFeedState>
newsFeedControllerProvider =
    AsyncNotifierProvider<NewsFeedController, NewsFeedState>(
      NewsFeedController.new,
    );
