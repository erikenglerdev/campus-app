// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Keys of the persistent content cache.
///
/// Keys carry the locale where the cached document is locale dependent, so a
/// language switch never shows the previous language's content.
abstract final class CacheKeys {
  /// Full channel list.
  static String newsChannels(String locale) => 'news.channels.$locale';

  /// The most recently loaded first page of the news list, keyed by the
  /// selected channel set so a channel change does not show a stale list.
  static String newsFirstPage(String locale, List<String> channels) {
    final List<String> sorted = List<String>.of(channels)..sort();
    return 'news.page1.$locale.${sorted.join('+')}';
  }

  /// Full contact area list.
  static String contactAreas(String locale) => 'contacts.areas.$locale';

  /// The contact search index: every area with its persons and rooms.
  static String contactSearchIndex(String locale) =>
      'contacts.searchIndex.$locale';

  /// A single contact area including its persons.
  static String contactArea(String locale, String slug) =>
      'contacts.area.$locale.$slug';

  /// Canteen list.
  static String canteens(String locale) => 'canteen.list.$locale';

  /// Menu of one canteen for the cached two-week window
  /// (current + upcoming week).
  static String canteenMenu(String locale, String slug) =>
      'canteen.menu.$locale.$slug';

  /// Full study group list of the timetable.
  static String timetableGroups(String locale) => 'timetable.groups.$locale';

  /// One requested timetable range.
  ///
  /// The key carries the locale, the **Campus** group id and both range bounds,
  /// so neither a language switch, another group nor another week can ever be
  /// served from a foreign cache entry.
  static String timetableEntries({
    required String locale,
    required String groupId,
    required String from,
    required String to,
  }) => 'timetable.entries.$locale.$groupId.$from.$to';

  /// Full room catalogue of the campus map.
  ///
  /// The catalogue is small and the client searches locally, so one entry per
  /// locale is enough and the map keeps working offline after a single fetch.
  static String rooms(String locale) => 'campusmap.rooms.$locale';

  /// Full public-calendar catalogue.
  static String publicCalendars(String locale) => 'calendars.public.$locale';

  /// Aggregated events of the SELECTED public calendars for one window.
  /// The key carries the locale, the sorted selection and both bounds, so
  /// another selection, week or language is never served from a foreign entry.
  static String publicCalendarEvents({
    required String locale,
    required List<String> slugs,
    required String from,
    required String to,
  }) {
    final List<String> sorted = List<String>.of(slugs)..sort();
    return 'calendars.public.events.$locale.${sorted.join('+')}.$from.$to';
  }
}
