// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../domain/read_state.dart';

/// Owns the locally stored read/unread state of announcements.
///
/// There is no account, so this never leaves the device and never reaches the
/// Campus API. Writes are fire-and-forget against the key/value store; the
/// in-memory state is updated first so the list reacts immediately.
class NewsReadController extends Notifier<NewsReadState> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  /// Whether this run started on an installation that had never seen a feed.
  ///
  /// It stays set for the whole run, so every page the user scrolls into is
  /// adopted as read — on a fresh install the articles further down the feed
  /// are older still, and none of them is news to somebody who has just
  /// arrived. The next launch reads `initialised` from the store and stops
  /// adopting.
  bool _adopting = false;

  @override
  NewsReadState build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    final NewsReadState stored = NewsReadState.fromStorage(
      readSlugs: store.getStringList(PreferenceKeys.newsReadSlugs),
      initialised: store.getInt(PreferenceKeys.newsReadInitialised) == 1,
    );
    _adopting = !stored.initialised;
    return stored;
  }

  /// Reconciles the stored state with what the feed currently holds.
  ///
  /// [complete] says whether [feedSlugs] is the **whole** feed rather than the
  /// pages loaded so far. Pruning against a partial feed would drop the marker
  /// of every article below it and make the archive unread again, so a partial
  /// feed only ever leaves the state alone.
  ///
  /// An **empty** feed is ignored outright: an outage or a failed response must
  /// not prune anything. The project rule that a failed response never destroys
  /// the last good state applies here too.
  Future<void> syncWithFeed(
    Iterable<String> feedSlugs, {
    required bool complete,
  }) async {
    final List<String> slugs = feedSlugs.toList(growable: false);
    if (slugs.isEmpty) return;
    final NewsReadState next = _adopting
        ? state.adopt(slugs)
        : complete
        ? state.prune(slugs)
        : state;
    if (next == state) return;
    await _write(next);
  }

  Future<void> markRead(String slug) => _write(state.markRead(slug));

  Future<void> markUnread(String slug) => _write(state.markUnread(slug));

  Future<void> markAllRead(Iterable<String> feedSlugs) =>
      _write(state.markAllRead(feedSlugs));

  Future<void> _write(NewsReadState next) async {
    state = next;
    await _store.setStringList(PreferenceKeys.newsReadSlugs, next.toStorage());
    await _store.setInt(
      PreferenceKeys.newsReadInitialised,
      next.initialised ? 1 : 0,
    );
  }
}

final NotifierProvider<NewsReadController, NewsReadState> newsReadProvider =
    NotifierProvider<NewsReadController, NewsReadState>(NewsReadController.new);

/// Whether the list is filtered to unread items only.
class NewsUnreadOnlyController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(keyValueStoreProvider).getInt(PreferenceKeys.newsUnreadOnly) ==
      1;

  Future<void> toggle() async {
    state = !state;
    await ref
        .read(keyValueStoreProvider)
        .setInt(PreferenceKeys.newsUnreadOnly, state ? 1 : 0);
  }
}

final NotifierProvider<NewsUnreadOnlyController, bool> newsUnreadOnlyProvider =
    NotifierProvider<NewsUnreadOnlyController, bool>(
      NewsUnreadOnlyController.new,
    );
