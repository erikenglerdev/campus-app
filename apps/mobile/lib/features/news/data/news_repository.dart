// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/cache_providers.dart';
import '../../../core/cache/content_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/cached_endpoint.dart';
import '../../../core/network/loaded.dart';
import '../../../core/network/network_providers.dart';
import 'news_models.dart';

/// Reads news content from the Campus API with a transparent offline cache.
class NewsRepository {
  NewsRepository({required ApiClient client, required ContentCache cache})
    : _endpoint = CachedEndpoint(client: client, cache: cache);

  final CachedEndpoint _endpoint;

  Future<Loaded<List<NewsChannel>>> fetchChannels({
    required String locale,
  }) async {
    return _endpoint.load<List<NewsChannel>>(
      path: '/news/channels',
      cacheKey: CacheKeys.newsChannels(locale),
      locale: locale,
      parse: NewsChannel.listFromJson,
    );
  }

  /// Loads a page of the news list.
  ///
  /// [channelsParameter] follows the API contract exactly:
  /// `null` omits the parameter (all channels), `''` sends it empty
  /// (deliberately no channels), otherwise a CSV of slugs.
  Future<Loaded<NewsPage>> fetchArticles({
    required String locale,
    required String? channelsParameter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final Loaded<List<NewsArticle>>
    loaded = await _endpoint.load<List<NewsArticle>>(
      path: '/news',
      cacheKey: CacheKeys.newsFirstPage(
        locale,
        channelsParameter == null || channelsParameter.isEmpty
            ? const <String>[]
            : channelsParameter.split(','),
      ),
      locale: locale,
      query: <String, Object?>{
        'channels': channelsParameter,
        'page': page,
        'pageSize': pageSize,
      },
      parse: NewsArticle.listFromJson,
      // Only the first page is cached; deeper pages always need the network.
      allowCacheFallback: page == 1,
    );

    return loaded.map(
      (List<NewsArticle> articles) => NewsPage(
        articles: articles,
        page: loaded.meta.pagination?.page ?? page,
        totalPages: loaded.meta.pagination?.totalPages ?? page,
      ),
    );
  }
}

final Provider<NewsRepository> newsRepositoryProvider =
    Provider<NewsRepository>(
      (Ref ref) => NewsRepository(
        client: ref.watch(apiClientProvider),
        cache: ref.watch(contentCacheProvider),
      ),
    );
