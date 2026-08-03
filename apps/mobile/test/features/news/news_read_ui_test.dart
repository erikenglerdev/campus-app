// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/news/application/news_read_controller.dart';
import 'package:campus_koethen/features/news/presentation/news_card.dart';
import 'package:campus_koethen/features/news/presentation/news_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/pump_app.dart';

Map<String, dynamic> _article(String slug, String title) => <String, dynamic>{
  'slug': slug,
  'title': title,
  'teaser': null,
  'publishedAt': '2026-05-12T09:00:00.000Z',
  'isPinned': false,
  'heroImage': null,
  'channels': <Object>[],
  'authors': <Object>[],
  'content': <Object>[],
};

Map<String, dynamic> _channel(String slug, String name) => <String, dynamic>{
  'slug': slug,
  'name': name,
  'sortOrder': 10,
  'defaultSubscribed': true,
};

ApiClient _api(List<Map<String, dynamic>> articles) => fakeApiClient(
  FakeHttpAdapter((RequestOptions options) {
    if (options.path.contains('/news/channels')) {
      return FakeHttpResponse(
        envelope(<Map<String, dynamic>>[_channel('stura', 'Studierendenrat')]),
      );
    }
    if (options.path.contains('/news')) {
      return FakeHttpResponse(envelope(articles));
    }
    return FakeHttpResponse(envelope(<Object>[]));
  }),
);

Future<ProviderContainer> pumpNews(
  WidgetTester tester, {
  List<Map<String, dynamic>>? articles,
  KeyValueStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = await pumpScreen(
    tester,
    const NewsListScreen(),
    locale: locale,
    keyValueStore: store,
    overrides: <Override>[
      apiClientProvider.overrideWithValue(
        _api(
          articles ??
              <Map<String, dynamic>>[
                _article('a', 'Erste Meldung'),
                _article('b', 'Zweite Meldung'),
              ],
        ),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a first install shows nothing as unread', (
    WidgetTester tester,
  ) async {
    // Announcing a backlog to someone opening the app for the first time
    // would be noise, not information.
    final ProviderContainer container = await pumpNews(tester);

    expect(find.text('Erste Meldung'), findsOneWidget);
    expect(find.text('Neu'), findsNothing);
    expect(container.read(newsReadProvider).initialised, isTrue);
  });

  testWidgets('an article added later is marked unread', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    // The install has already seen 'a'.
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>['a']);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    await pumpNews(tester, store: store);

    expect(find.text('Neu'), findsOneWidget);
    final NewsCard fresh = tester.widget<NewsCard>(
      find.ancestor(
        of: find.text('Zweite Meldung'),
        matching: find.byType(NewsCard),
      ),
    );
    expect(fresh.isUnread, isTrue);
  });

  testWidgets('unread is stated in words, not only by colour', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>['a']);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    await pumpNews(tester, store: store);

    // A visible badge…
    expect(find.text('Neu'), findsOneWidget);
    // …and an accessible name that says so too.
    expect(find.bySemanticsLabel(RegExp('Ungelesen')), findsOneWidget);
  });

  testWidgets('the unread-only filter hides read articles', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>['a']);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    await pumpNews(tester, store: store);
    expect(find.text('Erste Meldung'), findsOneWidget);

    await tester.tap(find.byTooltip('Nur ungelesene'));
    await tester.pumpAndSettle();

    expect(find.text('Erste Meldung'), findsNothing);
    expect(find.text('Zweite Meldung'), findsOneWidget);
    expect(store.getInt(PreferenceKeys.newsUnreadOnly), 1);
  });

  testWidgets('filtering to unread with nothing unread explains itself', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setInt(PreferenceKeys.newsUnreadOnly, 1);

    await pumpNews(tester, store: store);

    // "Nothing unread" is a different answer from "no announcements".
    expect(find.text('Alles gelesen.'), findsOneWidget);
    expect(find.text('Alle anzeigen'), findsWidgets);
  });

  testWidgets('mark all as read clears every badge', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>[]);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    final ProviderContainer container = await pumpNews(tester, store: store);
    expect(find.text('Neu'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Alle als gelesen markieren'));
    await tester.pumpAndSettle();

    expect(find.text('Neu'), findsNothing);
    expect(container.read(newsReadProvider).unreadCount(<String>['a', 'b']), 0);
    expect(
      store.getStringList(PreferenceKeys.newsReadSlugs),
      containsAll(<String>['a', 'b']),
    );
  });

  testWidgets('an empty feed does not wipe the read state', (
    WidgetTester tester,
  ) async {
    // An outage must never reset what the user has already read.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>['a', 'b']);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    final ProviderContainer container = await pumpNews(
      tester,
      articles: <Map<String, dynamic>>[],
      store: store,
    );

    expect(container.read(newsReadProvider).readSlugs, <String>{'a', 'b'});
    expect(
      store.getStringList(PreferenceKeys.newsReadSlugs),
      containsAll(<String>['a', 'b']),
    );
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpNews(tester, locale: AppLocales.english);
    expect(find.byTooltip('Unread only'), findsOneWidget);
    expect(find.byTooltip('Mark all as read'), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setStringList(PreferenceKeys.newsReadSlugs, <String>[]);
    await store.setInt(PreferenceKeys.newsReadInitialised, 1);

    await pumpScreen(
      tester,
      const NewsListScreen(),
      keyValueStore: store,
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[
        apiClientProvider.overrideWithValue(
          _api(<Map<String, dynamic>>[
            _article(
              'a',
              'Eine ziemlich lange Überschrift für den Umbruchtest',
            ),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
