// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

/// All route paths and names of the app in one place.
abstract final class AppRoutes {
  static const String news = '/news';
  static const String newsDetailName = 'news-detail';
  static const String newsDetailPath = ':slug';

  static const String canteen = '/canteen';

  static const String contacts = '/contacts';
  static const String contactAreaName = 'contact-area';
  static const String contactAreaPath = ':slug';

  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String imprint = '/settings/imprint';
  static const String privacy = '/settings/privacy';
  static const String channels = '/settings/channels';
}
