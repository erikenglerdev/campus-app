// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/api_failure.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:campus_koethen/features/news/data/news_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

Map<String, dynamic> get _article => <String, dynamic>{
  'slug': 'semesterstart-2026',
  'title': 'Semesterstart 2026',
  'teaser': 'Was zum Start wichtig ist.',
  'publishedAt': '2026-07-20T09:00:00.000Z',
  'isPinned': true,
  'heroImage': null,
  'channels': <Object>[
    <String, dynamic>{'slug': 'campus-news', 'name': 'Campus News'},
  ],
  'authors': <Object>[],
  'sourceName': null,
  'sourceUrl': null,
};

void main() {
  group('channels query parameter', () {
    test('is omitted when the repository is given null', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (_) => FakeHttpResponse(envelope(<Object>[_article])),
      );
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      await repository.fetchArticles(locale: 'de', channelsParameter: null);

      expect(adapter.queries.single, isNot(contains('channels')));
    });

    test('is present but empty when nothing is selected', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (_) => FakeHttpResponse(envelope(<Object>[])),
      );
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      await repository.fetchArticles(locale: 'de', channelsParameter: '');

      final String query = adapter.queries.single;
      expect(query, contains('channels='));
      expect(
        RegExp(r'channels=([^&]*)').firstMatch(query)!.group(1),
        isEmpty,
        reason: 'an empty value means "deliberately no channels"',
      );
    });

    test('carries the selected slugs as a CSV', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (_) => FakeHttpResponse(envelope(<Object>[_article])),
      );
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      await repository.fetchArticles(
        locale: 'de',
        channelsParameter: 'campus-news,fb5-news',
      );

      expect(
        Uri.decodeQueryComponent(
          RegExp(
            r'channels=([^&]*)',
          ).firstMatch(adapter.queries.single)!.group(1)!,
        ),
        'campus-news,fb5-news',
      );
    });

    test('sends the resolved locale', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (_) => FakeHttpResponse(envelope(<Object>[])),
      );
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      await repository.fetchArticles(locale: 'en', channelsParameter: null);

      expect(adapter.queries.single, contains('locale=en'));
    });
  });

  group('offline cache', () {
    test(
      'serves the last successful response when the network fails',
      () async {
        bool fail = false;
        final FakeHttpAdapter adapter = FakeHttpAdapter((_) {
          if (fail) throw Exception('offline');
          return FakeHttpResponse(envelope(<Object>[_article]));
        });
        final ContentCache cache = SafeContentCache(MemoryContentCache());
        final NewsRepository repository = NewsRepository(
          client: fakeApiClient(adapter),
          cache: cache,
        );

        final Loaded<NewsPage> live = await repository.fetchArticles(
          locale: 'de',
          channelsParameter: 'campus-news',
        );
        expect(live.fromCache, isFalse);
        expect(live.value.articles, hasLength(1));

        fail = true;
        final Loaded<NewsPage> cached = await repository.fetchArticles(
          locale: 'de',
          channelsParameter: 'campus-news',
        );
        expect(cached.fromCache, isTrue);
        expect(cached.cachedAt, isNotNull);
        expect(cached.value.articles.single.title, 'Semesterstart 2026');
      },
    );

    test('rethrows when neither network nor cache can serve', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter((_) {
        throw Exception('offline');
      });
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      expect(
        () => repository.fetchArticles(
          locale: 'de',
          channelsParameter: 'campus-news',
        ),
        throwsA(isA<ApiFailure>()),
      );
    });

    test('maps a 404 to a not-found failure', () async {
      final FakeHttpAdapter adapter = FakeHttpAdapter(
        (_) => const FakeHttpResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'status': 404,
            'code': 'NEWS_ARTICLE_NOT_FOUND',
            'message': 'nicht gefunden',
          },
        }, statusCode: 404),
      );
      final NewsRepository repository = NewsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );

      await expectLater(
        repository.fetchArticle(locale: 'de', slug: 'missing'),
        throwsA(
          isA<ApiFailure>()
              .having(
                (ApiFailure failure) => failure.kind,
                'kind',
                ApiFailureKind.notFound,
              )
              .having(
                (ApiFailure failure) => failure.code,
                'code',
                'NEWS_ARTICLE_NOT_FOUND',
              ),
        ),
      );
    });
  });
}
