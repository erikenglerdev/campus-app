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

  // --- Public calendars (Y-of-X selection, non-sensitive) ------------------

  /// Schema version of the public-calendar selection store.
  static const String publicCalendarStoreVersion = 'calendars.public.version';

  /// Every public-calendar slug the app has ever seen. Guards
  /// `defaultSubscribed` so it is evaluated exactly once per slug.
  static const String publicCalendarSeenSlugs = 'calendars.public.seen.v1';

  /// The public-calendar slugs the user has currently activated.
  static const String publicCalendarSelectedSlugs =
      'calendars.public.selected.v1';

  /// Current schema version of the public-calendar selection store.
  static const int publicCalendarStoreCurrentVersion = 1;

  // --- Personalisation (mobile-first redesign) -----------------------------

  /// Storage value of the chosen [AccentPalette].
  static const String accentPalette = 'settings.accentPalette.v1';

  /// `1` when the user asked for reduced motion locally. The operating
  /// system's own setting is honoured independently of this flag.
  static const String reducedMotion = 'settings.reducedMotion.v1';

  /// The four user-chosen modules of the bottom navigation bar, as module
  /// storage values in bar order.
  ///
  /// `v2`: the bar used to be a fixed first tab, three configurable middles and
  /// More. It is now four free slots and More, over a different catalogue, so a
  /// `v1` list would repair into something the user never chose. A new key lets
  /// the old value be ignored rather than misread.
  static const String navigationTabs = 'settings.navigation.tabs.v2';

  /// buildingKey of the building the campus map opens on.
  static const String defaultBuilding = 'settings.defaultBuilding.v1';

  /// `1` once the first-run onboarding has been completed or skipped.
  static const String onboardingCompleted = 'settings.onboarding.completed.v1';

  /// Slugs of announcements the user has read. Pruned against the feed on
  /// every load, so this cannot grow without bound.
  static const String newsReadSlugs = 'news.read.slugs.v1';

  /// `1` once this installation has seen a news feed at all. Distinguishes
  /// "nothing read yet" from "brand new install".
  static const String newsReadInitialised = 'news.read.initialised.v1';

  /// `1` while the news list is filtered to unread items only.
  static const String newsUnreadOnly = 'news.filter.unreadOnly.v1';

  /// Semantic properties a dish must have, as `MealTrait` keys.
  ///
  /// A new key rather than the old `canteen.filter.required.v1`: that one held
  /// the source's own marker codes. Those are a different vocabulary, and
  /// adopting them unchecked would turn "avoid code 52" into "avoid something
  /// else entirely" the day the source renumbers.
  static const String canteenTraits = 'canteen.filter.traits.v1';

  /// Allergens to avoid, as `MealAllergen` keys. New key for the same reason.
  static const String canteenAllergens = 'canteen.filter.allergens.v1';

  /// The one price group the cards show. Version 2: the value is no longer
  /// optional, and an absent key now means "student" rather than "the API's
  /// own emphasis".
  static const String canteenPriceGroup = 'canteen.filter.priceGroup.v2';

  /// Names of starred dishes. Names, not upstream ids — those change weekly.
  static const String canteenFavourites = 'canteen.favourites.v1';

  /// Calendar sources the user switched OFF, as source storage values.
  ///
  /// Stored as the disabled set rather than the enabled one on purpose: a
  /// source added in a later version is then on by default instead of
  /// invisible until the user finds the filter.
  static const String calendarDisabledSources = 'calendar.sources.off.v1';

  /// `1` while the week view also draws Saturday and Sunday.
  ///
  /// Default off: a teaching week is Monday to Friday, and two empty columns
  /// cost a fifth of the width of a phone.
  static const String calendarShowWeekend = 'calendar.weekend.v1';
}
