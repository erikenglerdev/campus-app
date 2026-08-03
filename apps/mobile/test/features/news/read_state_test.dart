// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/features/news/domain/read_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a fresh install', () {
    test('starts with nothing read and uninitialised', () {
      expect(NewsReadState.empty.readSlugs, isEmpty);
      expect(NewsReadState.empty.initialised, isFalse);
    });

    test('treats the first feed as already read', () {
      // Announcing "23 unread" to someone opening the app for the first time
      // would be noise, not information.
      final NewsReadState state = NewsReadState.empty.withFeed(<String>[
        'a',
        'b',
        'c',
      ]);
      expect(state.unreadCount(<String>['a', 'b', 'c']), 0);
      expect(state.initialised, isTrue);
    });

    test('marks genuinely new articles unread on the next feed', () {
      final NewsReadState first = NewsReadState.empty.withFeed(<String>[
        'a',
        'b',
      ]);
      final NewsReadState second = first.withFeed(<String>['a', 'b', 'new']);

      expect(second.isUnread('new'), isTrue);
      expect(second.isRead('a'), isTrue);
      expect(second.unreadCount(<String>['a', 'b', 'new']), 1);
    });
  });

  group('reading', () {
    test('marking one read leaves the others alone', () {
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a'])
          .withFeed(<String>['a', 'b', 'c'])
          .markRead('b');

      expect(state.isRead('b'), isTrue);
      expect(state.isUnread('c'), isTrue);
    });

    test('marking all read clears the count', () {
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a'])
          .withFeed(<String>['a', 'b', 'c']);
      expect(state.unreadCount(<String>['a', 'b', 'c']), 2);

      final NewsReadState after = state.markAllRead(<String>['a', 'b', 'c']);
      expect(after.unreadCount(<String>['a', 'b', 'c']), 0);
    });

    test('an article can be marked unread again', () {
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a'])
          .markUnread('a');
      expect(state.isUnread('a'), isTrue);
      expect(
        state.initialised,
        isTrue,
        reason: 'un-reading one article does not make the install new again',
      );
    });
  });

  group('pruning against the feed', () {
    test('drops markers for articles the feed no longer serves', () {
      // A deactivated channel, or an unpublished post. Keeping its marker
      // forever would grow the store without bound.
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a', 'b', 'gone'])
          .withFeed(<String>['a', 'b']);

      expect(state.readSlugs, <String>{'a', 'b'});
    });

    test('an article that comes back is new again', () {
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a', 'temporarily-gone'])
          .withFeed(<String>['a'])
          .withFeed(<String>['a', 'temporarily-gone']);

      expect(
        state.isUnread('temporarily-gone'),
        isTrue,
        reason: 'it left the feed, so its read marker legitimately went too',
      );
    });

    test('an empty feed does not wipe an initialised install', () {
      // An outage or an empty response must not silently reset read state.
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['a', 'b'])
          .withFeed(<String>['a', 'b'])
          .markAllRead(<String>['a', 'b']);

      expect(state.initialised, isTrue);
      expect(state.unreadCount(<String>[]), 0);
    });
  });

  group('counting', () {
    test('counts only what is in the feed', () {
      final NewsReadState state = NewsReadState.fromStorage(
        readSlugs: <String>['a'],
        initialised: true,
      );
      expect(state.unreadCount(<String>['a', 'b']), 1);
      expect(state.unreadCount(<String>['a']), 0);
      expect(state.unreadCount(<String>[]), 0);
    });
  });

  group('storage', () {
    test('round-trips', () {
      final NewsReadState state = NewsReadState.empty
          .withFeed(<String>['b', 'a'])
          .markRead('c');
      final NewsReadState reloaded = NewsReadState.fromStorage(
        readSlugs: state.toStorage(),
        initialised: true,
      );
      expect(reloaded, state);
    });

    test('is written in a stable order so the store does not churn', () {
      final NewsReadState state = NewsReadState.empty.withFeed(<String>[
        'c',
        'a',
        'b',
      ]);
      expect(state.toStorage(), <String>['a', 'b', 'c']);
    });
  });
}
