// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/api_client.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/features/news/application/news_read_controller.dart';
import 'package:campus_koethen/features/news/presentation/news_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/news_harness.dart';
import '../../support/pump_app.dart';

Map<String, dynamic> _article(String slug, String title) => <String, dynamic>{
  'slug': slug,
  'title': title,
  'teaser': null,
  'publishedAt': '2026-08-04T09:00:00.000Z',
  'isPinned': false,
  'heroImage': null,
  'channels': <Object>[],
  'authors': <Object>[],
  'content': <Object>[
    <String, dynamic>{
      'type': 'paragraph',
      'children': <Object>[
        <String, dynamic>{'type': 'text', 'text': 'Der Text von $slug.'},
      ],
    },
  ],
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
      frozenNewsClock(),
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

/// Opens the one filter button at the top of the feed.
Future<void> _openFilters(
  WidgetTester tester, {
  String tooltip = 'Filter',
}) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

/// Closes the modal sheet by tapping its barrier.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

/// Lets the visibility dwell of any unread card elapse.
///
/// Every test that renders an unread article has to do this before it ends —
/// the timer is the feature, and a test that left it pending would fail.
Future<void> _letDwellElapse(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
}

InMemoryKeyValueStore _knownInstall({List<String> read = const <String>[]}) {
  return InMemoryKeyValueStore(<String, Object>{
    PreferenceKeys.newsReadSlugs: read,
    PreferenceKeys.newsReadInitialised: 1,
  });
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
    // The install has already seen 'a'.
    await pumpNews(tester, store: _knownInstall(read: <String>['a']));

    expect(find.text('Neu'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Zweite Meldung'),
          matching: find.byType(Card),
        ),
        matching: find.text('Neu'),
      ),
      findsOneWidget,
    );

    await _letDwellElapse(tester);
  });

  testWidgets('unread is stated in words, not only by colour', (
    WidgetTester tester,
  ) async {
    await pumpNews(tester, store: _knownInstall(read: <String>['a']));

    // A visible badge…
    expect(find.text('Neu'), findsOneWidget);
    // …and an accessible name that says so too.
    expect(find.bySemanticsLabel(RegExp('Ungelesen')), findsOneWidget);

    await _letDwellElapse(tester);
  });

  testWidgets('an article that stays on screen is marked read by itself', (
    WidgetTester tester,
  ) async {
    // Not the moment the list builds the card — a card is built shortly before
    // it scrolls into view, and building is not reading.
    final InMemoryKeyValueStore store = _knownInstall();
    final ProviderContainer container = await pumpNews(tester, store: store);
    expect(container.read(newsReadProvider).unreadCount(<String>['a', 'b']), 2);

    await _letDwellElapse(tester);

    expect(container.read(newsReadProvider).unreadCount(<String>['a', 'b']), 0);
    expect(find.text('Neu'), findsNothing);
  });

  testWidgets('the filter sheet holds the unread switch', (
    WidgetTester tester,
  ) async {
    // One button at the top, everything behind it: channels and unread live in
    // the same sheet.
    final InMemoryKeyValueStore store = _knownInstall(read: <String>['a']);
    await pumpNews(tester, store: store);

    await _openFilters(tester);
    expect(find.text('Kanäle'), findsOneWidget);
    await tester.tap(find.text('Nur ungelesene'));
    await tester.pumpAndSettle();

    expect(store.getInt(PreferenceKeys.newsUnreadOnly), 1);

    await _closeSheet(tester);
  });

  testWidgets('the unread-only filter hides read articles', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = _knownInstall(read: <String>['a']);
    await store.setInt(PreferenceKeys.newsUnreadOnly, 1);

    await pumpNews(tester, store: store);

    expect(find.text('Erste Meldung'), findsNothing);
    expect(find.text('Zweite Meldung'), findsOneWidget);

    await _letDwellElapse(tester);

    // With the filter on nothing is marked read by looking at it, or the
    // article would vanish from under the reader's finger.
    expect(find.text('Neu'), findsOneWidget);
    expect(find.text('Zweite Meldung'), findsOneWidget);
  });

  testWidgets('filtering to unread with nothing unread explains itself', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = _knownInstall(read: <String>['a', 'b']);
    await store.setInt(PreferenceKeys.newsUnreadOnly, 1);

    await pumpNews(tester, store: store);

    // "Nothing unread" is a different answer from "no announcements".
    expect(find.text('Alles gelesen.'), findsOneWidget);
    expect(find.text('Alle anzeigen'), findsWidgets);
  });

  testWidgets('mark all as read clears every badge', (
    WidgetTester tester,
  ) async {
    final InMemoryKeyValueStore store = _knownInstall();
    final ProviderContainer container = await pumpNews(tester, store: store);
    expect(find.text('Neu'), findsNWidgets(2));

    await _openFilters(tester);
    await tester.tap(find.text('Alle als gelesen markieren'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);

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
    final InMemoryKeyValueStore store = _knownInstall(read: <String>['a', 'b']);

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

    await _openFilters(tester);
    expect(find.text('Unread only'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
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

    await pumpScreen(
      tester,
      const NewsListScreen(),
      keyValueStore: _knownInstall(),
      textScaler: const TextScaler.linear(2),
      overrides: <Override>[
        frozenNewsClock(),
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

    await _letDwellElapse(tester);
  });
}
