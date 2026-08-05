// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/news/application/news_read_controller.dart';
import 'package:campus_koethen/features/news/domain/read_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(InMemoryKeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

InMemoryKeyValueStore _knownInstall(List<String> read) {
  return InMemoryKeyValueStore(<String, Object>{
    PreferenceKeys.newsReadSlugs: read,
    PreferenceKeys.newsReadInitialised: 1,
  });
}

void main() {
  test('a partially loaded feed never prunes the markers below it', () async {
    // The feed loads page by page. Pruning against page one would delete the
    // read marker of every article further down, and the whole archive would
    // turn unread the moment the user opened the app.
    final InMemoryKeyValueStore store = _knownInstall(<String>[
      'page1',
      'page2',
    ]);
    final ProviderContainer container = _container(store);

    await container.read(newsReadProvider.notifier).syncWithFeed(<String>[
      'page1',
    ], complete: false);

    expect(container.read(newsReadProvider).readSlugs, <String>{
      'page1',
      'page2',
    });
  });

  test('the complete feed prunes what it no longer serves', () async {
    final InMemoryKeyValueStore store = _knownInstall(<String>['a', 'gone']);
    final ProviderContainer container = _container(store);

    await container.read(newsReadProvider.notifier).syncWithFeed(<String>[
      'a',
    ], complete: true);

    expect(container.read(newsReadProvider).readSlugs, <String>{'a'});
    expect(store.getStringList(PreferenceKeys.newsReadSlugs), <String>['a']);
  });

  test('an empty feed changes nothing at all', () async {
    // An outage or an empty response must not silently reset read state.
    final InMemoryKeyValueStore store = _knownInstall(<String>['a', 'b']);
    final ProviderContainer container = _container(store);

    await container
        .read(newsReadProvider.notifier)
        .syncWithFeed(const <String>[], complete: true);

    expect(container.read(newsReadProvider).readSlugs, <String>{'a', 'b'});
  });

  group('a fresh install', () {
    test('adopts the first page even though it is incomplete', () async {
      final ProviderContainer container = _container(InMemoryKeyValueStore());

      await container.read(newsReadProvider.notifier).syncWithFeed(<String>[
        'a',
        'b',
      ], complete: false);

      final NewsReadState state = container.read(newsReadProvider);
      expect(state.unreadCount(<String>['a', 'b']), 0);
      expect(state.initialised, isTrue);
    });

    test('keeps adopting the pages the user scrolls into', () async {
      // Older articles are not news to somebody who has just installed the app.
      final ProviderContainer container = _container(InMemoryKeyValueStore());
      final NewsReadController controller = container.read(
        newsReadProvider.notifier,
      );

      await controller.syncWithFeed(<String>['a'], complete: false);
      await controller.syncWithFeed(<String>['a', 'b'], complete: true);

      expect(
        container.read(newsReadProvider).unreadCount(<String>['a', 'b']),
        0,
      );
    });

    test('the next launch is no longer adopting', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await _container(store).read(newsReadProvider.notifier).syncWithFeed(
        <String>['a'],
        complete: true,
      );

      // Same store, new run: an article that appeared meanwhile is genuinely
      // new and must stay unread.
      final ProviderContainer restarted = _container(store);
      await restarted.read(newsReadProvider.notifier).syncWithFeed(<String>[
        'a',
        'new',
      ], complete: true);

      expect(restarted.read(newsReadProvider).isUnread('new'), isTrue);
    });
  });
}
