// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/news/application/news_providers.dart';
import 'package:campus_koethen/features/news/presentation/news_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import '../../support/throwing_content_cache.dart';

FakeHttpAdapter workingApi({List<Map<String, dynamic>>? articles}) {
  return FakeHttpAdapter((RequestOptions options) {
    if (options.path.endsWith('/news/channels')) {
      return FakeHttpResponse(envelope(channelsFixture));
    }
    return FakeHttpResponse(
      envelope(
        articles ?? articlesFixture,
        meta: <String, dynamic>{
          'pagination': <String, dynamic>{
            'page': 1,
            'pageSize': 20,
            'total': (articles ?? articlesFixture).length,
            'totalPages': 1,
          },
        },
      ),
    );
  });
}

void main() {
  testWidgets('renders the article list', (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const NewsListScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(workingApi())),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Semesterstart 2026'), findsOneWidget);
    expect(find.text('Angepinnt'), findsOneWidget);
  });

  testWidgets('a throwing cache still yields a working screen', (
    WidgetTester tester,
  ) async {
    final ThrowingContentCache cache = ThrowingContentCache();

    await pumpScreen(
      tester,
      const NewsListScreen(),
      contentCache: cache,
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(workingApi())),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(cache.writeAttempts, greaterThan(0), reason: 'the cache was used');
    expect(
      find.text('Semesterstart 2026'),
      findsOneWidget,
      reason: 'a broken cache degrades to a plain network fetch',
    );
  });

  testWidgets('a throwing cache degrades a network error to the error state', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const NewsListScreen(),
      contentCache: ThrowingContentCache(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          fakeApiClient(
            FakeHttpAdapter((RequestOptions _) => throw Exception('offline')),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Etwas ist schiefgelaufen'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets(
    'shows a dedicated empty state when every channel is deselected',
    (WidgetTester tester) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{
          PreferenceKeys.channelStoreVersion:
              PreferenceKeys.channelStoreCurrentVersion,
          PreferenceKeys.channelSeenSlugs: <String>['campus-news', 'fb5-news'],
          PreferenceKeys.channelSelectedSlugs: <String>[],
        },
      );
      final FakeHttpAdapter adapter = workingApi(
        articles: <Map<String, dynamic>>[],
      );

      await pumpScreen(
        tester,
        const NewsListScreen(),
        keyValueStore: store,
        overrides: <Override>[
          apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Keine Kanäle ausgewählt'), findsOneWidget);

      final String newsQuery = adapter.requests
          .firstWhere(
            (RequestOptions options) => !options.path.contains('channels'),
          )
          .uri
          .query;
      expect(
        newsQuery,
        contains('channels='),
        reason: 'the parameter must be present but empty, never omitted',
      );
    },
  );

  testWidgets('shows the empty state when a channel has no articles', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const NewsListScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          fakeApiClient(workingApi(articles: <Map<String, dynamic>>[])),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Keine Beiträge'), findsOneWidget);
  });

  testWidgets('renders English when the locale is en', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const NewsListScreen(),
      locale: AppLocales.english,
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          fakeApiClient(workingApi(articles: <Map<String, dynamic>>[])),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('No articles'), findsOneWidget);
    expect(find.text('Keine Beiträge'), findsNothing);
  });

  testWidgets('labels cached content as offline', (WidgetTester tester) async {
    bool offline = false;
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      if (offline) throw Exception('offline');
      if (options.path.endsWith('/news/channels')) {
        return FakeHttpResponse(envelope(channelsFixture));
      }
      return FakeHttpResponse(envelope(articlesFixture));
    });

    final ProviderContainer container = await pumpScreen(
      tester,
      const NewsListScreen(),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline gespeicherte Inhalte'), findsNothing);

    offline = true;
    container.invalidate(newsFeedProvider);
    await tester.pumpAndSettle();

    expect(find.text('Offline gespeicherte Inhalte'), findsOneWidget);
    expect(find.text('Semesterstart 2026'), findsOneWidget);
  });
}
