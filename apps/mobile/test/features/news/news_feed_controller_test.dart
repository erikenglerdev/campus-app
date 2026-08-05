// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/news/application/channel_subscriptions.dart';
import 'package:campus_koethen/features/news/application/news_feed_controller.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

Map<String, dynamic> _article(String slug) => <String, dynamic>{
  'slug': slug,
  'title': 'Titel $slug',
  'teaser': '',
  'publishedAt': '2026-07-20T09:00:00.000Z',
  'isPinned': false,
  'heroImage': null,
  'channels': <Object>[],
  'authors': <Object>[],
  'sourceName': null,
  'sourceUrl': null,
  'content': <Object>[],
};

Map<String, dynamic> get _channel => <String, dynamic>{
  'slug': 'campus-news',
  'name': 'Campus News',
  'description': null,
  'iconKey': 'campus',
  'colorHex': '#5B3FD0',
  'sortOrder': 0,
  'defaultSubscribed': true,
};

/// Answers channels once and then serves scripted article pages.
class _Feed {
  _Feed(this.pages);

  /// page number -> slugs, or `null` to make that page fail.
  final Map<int, List<String>?> pages;
  final List<int> requestedPages = <int>[];

  FakeHttpAdapter get adapter => FakeHttpAdapter((RequestOptions options) {
    if (options.path.contains('channels')) {
      return FakeHttpResponse(envelope(<Object>[_channel]));
    }
    final int page =
        int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
    requestedPages.add(page);
    final List<String>? slugs = pages[page];
    if (slugs == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return FakeHttpResponse(
      envelope(
        slugs.map(_article).toList(),
        meta: <String, dynamic>{
          'pagination': <String, dynamic>{
            'page': page,
            'pageSize': 2,
            'total': 4,
            'totalPages': pages.length,
          },
        },
      ),
    );
  });
}

ProviderContainer _container(_Feed feed) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      contentCacheProvider.overrideWithValue(
        SafeContentCache(MemoryContentCache()),
      ),
      apiClientProvider.overrideWithValue(fakeApiClient(feed.adapter)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

List<String> _slugs(NewsFeedState state) =>
    state.articles.map((NewsArticle a) => a.slug).toList();

void main() {
  // localeCodeProvider reads the platform locale through the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the first page is what the feed starts with', () async {
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a', 'b'],
      2: <String>['c', 'd'],
    });
    final ProviderContainer container = _container(feed);

    final NewsFeedState state = await container.read(
      newsFeedControllerProvider.future,
    );

    expect(_slugs(state), <String>['a', 'b']);
    expect(state.hasMore, isTrue);
    expect(feed.requestedPages, <int>[1]);
  });

  test('the next page is appended, not substituted', () async {
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a', 'b'],
      2: <String>['c', 'd'],
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);

    await container.read(newsFeedControllerProvider.notifier).loadMore();

    expect(_slugs(container.read(newsFeedControllerProvider).value!), <String>[
      'a',
      'b',
      'c',
      'd',
    ]);
  });

  test('an article on two pages appears once', () async {
    // The server sorts pinned articles first; one pinned between two requests
    // legitimately turns up twice.
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a', 'b'],
      2: <String>['b', 'c'],
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);

    await container.read(newsFeedControllerProvider.notifier).loadMore();

    expect(_slugs(container.read(newsFeedControllerProvider).value!), <String>[
      'a',
      'b',
      'c',
    ]);
  });

  test('a failed page keeps everything already loaded', () async {
    // Losing a screenful because the next request timed out is far worse than
    // a retry button at the bottom.
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a', 'b'],
      2: null,
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);

    await container.read(newsFeedControllerProvider.notifier).loadMore();

    final NewsFeedState state = container
        .read(newsFeedControllerProvider)
        .value!;
    expect(_slugs(state), <String>['a', 'b']);
    expect(state.loadMoreFailed, isTrue);
    expect(state.isLoadingMore, isFalse);
    // Still offering more, so the footer can retry.
    expect(state.hasMore, isTrue);
  });

  test('a retry after a failure appends the page', () async {
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a'],
      2: null,
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);
    await container.read(newsFeedControllerProvider.notifier).loadMore();

    feed.pages[2] = <String>['b'];
    await container.read(newsFeedControllerProvider.notifier).loadMore();

    final NewsFeedState state = container
        .read(newsFeedControllerProvider)
        .value!;
    expect(_slugs(state), <String>['a', 'b']);
    expect(state.loadMoreFailed, isFalse);
  });

  test('the last page is not asked for again', () async {
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a'],
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);

    expect(container.read(newsFeedControllerProvider).value!.hasMore, isFalse);
    await container.read(newsFeedControllerProvider.notifier).loadMore();

    expect(feed.requestedPages, <int>[1]);
  });

  test('refreshing starts again at page one', () async {
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a'],
      2: <String>['b'],
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);
    await container.read(newsFeedControllerProvider.notifier).loadMore();

    await container.read(newsFeedControllerProvider.notifier).refresh();

    final NewsFeedState state = container
        .read(newsFeedControllerProvider)
        .value!;
    expect(_slugs(state), <String>['a']);
    expect(state.page, 1);
  });

  test('changing the channel selection starts over at page one', () async {
    // Page three of the old selection says nothing about the new one.
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a'],
      2: <String>['b'],
    });
    final ProviderContainer container = _container(feed);
    await container.read(newsFeedControllerProvider.future);
    await container.read(newsFeedControllerProvider.notifier).loadMore();
    expect(feed.requestedPages, <int>[1, 2]);

    await container
        .read(channelSubscriptionProvider.notifier)
        .setSubscribed('campus-news', subscribed: false);
    final NewsFeedState state = await container.read(
      newsFeedControllerProvider.future,
    );

    expect(state.page, 1);
    expect(feed.requestedPages, <int>[1, 2, 1]);
  });

  test('each article carries the content the list endpoint delivers', () async {
    // Which is what lets the feed render inline without a request per card.
    final _Feed feed = _Feed(<int, List<String>?>{
      1: <String>['a'],
    });
    final ProviderContainer container = _container(feed);

    final NewsFeedState state = await container.read(
      newsFeedControllerProvider.future,
    );
    expect(state.articles.single.content, isEmpty);
    expect(feed.requestedPages, <int>[1]);
  });
}
