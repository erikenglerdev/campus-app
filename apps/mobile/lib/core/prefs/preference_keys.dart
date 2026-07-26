// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// All `shared_preferences` keys used by the app.
///
/// Keys are versioned. Bumping a version is how a breaking storage change is
/// rolled out without corrupting an existing installation.
abstract final class PreferenceKeys {
  /// `system` | `de` | `en`
  static const String localeMode = 'settings.localeMode.v1';

  /// `system` | `light` | `dark`
  static const String themeMode = 'settings.themeMode.v1';

  /// Canteen slug, or absent when the user has not chosen one yet.
  static const String preferredCanteen = 'settings.preferredCanteen.v1';

  /// **Campus** UUID of the chosen timetable group, or absent when the user has
  /// not chosen one yet. An upstream identifier is never stored.
  static const String preferredTimetableGroup =
      'settings.preferredTimetableGroup.v1';

  /// Schema version of the news channel subscription store.
  static const String channelStoreVersion = 'news.channels.version';

  /// Every channel slug the app has ever seen. Guards `defaultSubscribed` so
  /// it is evaluated exactly once per slug.
  static const String channelSeenSlugs = 'news.channels.seen.v1';

  /// The slugs the user is currently subscribed to.
  static const String channelSelectedSlugs = 'news.channels.selected.v1';

  /// `1` when the mail sync should also download attachment bytes for offline
  /// use, absent/`0` otherwise. Stored as an int flag.
  static const String mailDownloadAttachments = 'mail.downloadAttachments.v1';

  /// Current schema version of the channel subscription store.
  static const int channelStoreCurrentVersion = 1;
}
