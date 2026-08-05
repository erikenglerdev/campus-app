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
/// it is new again. Pruning is only ever valid against the **whole** feed,
/// which is why [adopt] and [prune] are two separate operations rather than one
/// "apply this feed" method: the feed arrives page by page.
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

  /// Takes everything in [feedSlugs] as already read.
  ///
  /// This is what an installation that has never seen a feed does with what it
  /// finds: nothing published before the app existed on this device is news.
  /// Slugs are **added**, because the feed arrives one page at a time and each
  /// further page is older than the last.
  NewsReadState adopt(Iterable<String> feedSlugs) => NewsReadState(
    readSlugs: <String>{...readSlugs, ...feedSlugs},
    initialised: true,
  );

  /// Drops markers for articles the feed no longer serves.
  ///
  /// [feedSlugs] must be the **complete** feed — a partial page would take
  /// every article below it with it.
  NewsReadState prune(Iterable<String> feedSlugs) => NewsReadState(
    readSlugs: readSlugs.intersection(feedSlugs.toSet()),
    initialised: initialised,
  );

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
