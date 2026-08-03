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

  @override
  NewsReadState build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    return NewsReadState.fromStorage(
      readSlugs: store.getStringList(PreferenceKeys.newsReadSlugs),
      initialised: store.getInt(PreferenceKeys.newsReadInitialised) == 1,
    );
  }

  /// Reconciles the stored state with a freshly loaded feed.
  ///
  /// Deliberately ignores an **empty** feed: an outage or a failed response
  /// would otherwise prune every marker and make the whole archive unread the
  /// next time it loads. The project rule that a failed response never
  /// destroys the last good state applies here too.
  Future<void> syncWithFeed(Iterable<String> feedSlugs) async {
    final List<String> slugs = feedSlugs.toList(growable: false);
    if (slugs.isEmpty) return;
    final NewsReadState next = state.withFeed(slugs);
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
