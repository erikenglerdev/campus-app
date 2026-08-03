// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// Which announcements the user has already read.
///
/// Entirely on-device. There is no Campus Köthen account, so read state is a
/// property of *this installation* and never leaves it.
///
/// Two decisions worth stating:
///
/// **A fresh install starts with everything read.** Otherwise the first launch
/// would announce dozens of unread items the user has no relationship with,
/// and the badge would be noise from the very first second. The moment the app
/// has seen a feed once, anything genuinely new is unread. This mirrors how
/// channel subscriptions already treat "seen" slugs.
///
/// **Read markers are pruned against the feed.** An article that is no longer
/// served — a deactivated channel, an unpublished post — drops out, which both
/// bounds the stored set and keeps it honest: if that article ever comes back
/// it is new again.
@immutable
class NewsReadState {
  const NewsReadState({required this.readSlugs, required this.initialised});

  /// Slugs the user has read.
  final Set<String> readSlugs;

  /// Whether this installation has ever seen a feed.
  ///
  /// Distinguishes "nothing read yet" from "brand new install", which need
  /// opposite answers for the same empty set.
  final bool initialised;

  static const NewsReadState empty = NewsReadState(
    readSlugs: <String>{},
    initialised: false,
  );

  bool isRead(String slug) => readSlugs.contains(slug);

  bool isUnread(String slug) => !isRead(slug);

  /// How many of [feedSlugs] are unread.
  int unreadCount(Iterable<String> feedSlugs) =>
      feedSlugs.where(isUnread).length;

  /// Applies a freshly loaded feed.
  ///
  /// On the very first feed everything counts as read; afterwards only the
  /// pruning happens, so new articles stay unread.
  NewsReadState withFeed(Iterable<String> feedSlugs) {
    final Set<String> feed = feedSlugs.toSet();
    if (!initialised) {
      return NewsReadState(readSlugs: feed, initialised: true);
    }
    return NewsReadState(
      // Keep only what the feed still knows about.
      readSlugs: readSlugs.intersection(feed),
      initialised: true,
    );
  }

  NewsReadState markRead(String slug) =>
      NewsReadState(readSlugs: <String>{...readSlugs, slug}, initialised: true);

  NewsReadState markUnread(String slug) => NewsReadState(
    readSlugs: readSlugs.where((String s) => s != slug).toSet(),
    initialised: initialised,
  );

  /// Marks everything currently in the feed as read.
  NewsReadState markAllRead(Iterable<String> feedSlugs) => NewsReadState(
    readSlugs: <String>{...readSlugs, ...feedSlugs},
    initialised: true,
  );

  List<String> toStorage() => readSlugs.toList(growable: false)..sort();

  static NewsReadState fromStorage({
    List<String>? readSlugs,
    required bool initialised,
  }) => NewsReadState(
    readSlugs: (readSlugs ?? const <String>[]).toSet(),
    initialised: initialised,
  );

  @override
  bool operator ==(Object other) =>
      other is NewsReadState &&
      setEquals(other.readSlugs, readSlugs) &&
      other.initialised == initialised;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(readSlugs), initialised);
}
