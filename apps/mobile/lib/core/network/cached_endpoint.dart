// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import '../cache/content_cache.dart';
import 'api_client.dart';
import 'api_meta.dart';
import 'json.dart';
import 'loaded.dart';

/// Fetches an endpoint and keeps its raw envelope in the content cache.
///
/// The cache stores the untouched `{ data, meta }` envelope, so a cached read
/// goes through exactly the same parser as a live read. Cache access is
/// wrapped in [SafeContentCache] by construction, therefore a broken cache
/// degrades this call to a plain network fetch instead of failing.
class CachedEndpoint {
  const CachedEndpoint({required this.client, required this.cache});

  final ApiClient client;
  final ContentCache cache;

  Future<Loaded<T>> load<T>({
    required String path,
    required String cacheKey,
    required T Function(Object? data) parse,
    Map<String, Object?> query = const <String, Object?>{},
    String? locale,
    bool allowCacheFallback = true,
  }) async {
    try {
      final ApiResponse<Object?> response = await client.get<Object?>(
        path,
        parse: (Object? data) => data,
        query: query,
        locale: locale,
      );
      await cache.write(cacheKey, <String, dynamic>{
        'data': response.data,
        'meta': response.meta.toJson(),
      });
      return Loaded<T>(value: parse(response.data), meta: response.meta);
    } catch (error) {
      if (!allowCacheFallback) rethrow;
      final Loaded<T>? cached = await _readCache<T>(cacheKey, parse);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Loaded<T>?> _readCache<T>(
    String cacheKey,
    T Function(Object? data) parse,
  ) async {
    final CacheEntry? entry = await cache.read(cacheKey);
    if (entry == null) return null;
    try {
      return Loaded<T>(
        value: parse(entry.payload['data']),
        meta: ApiMeta.fromJson(asJsonMap(entry.payload['meta'])),
        fromCache: true,
        cachedAt: entry.cachedAt,
      );
    } catch (_) {
      // A cached document that no longer parses is simply ignored.
      return null;
    }
  }
}
