// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

/// All route paths and names of the app in one place.
abstract final class AppRoutes {
  static const String news = '/news';
  static const String newsDetailName = 'news-detail';
  static const String newsDetailPath = ':slug';

  /// The second top-level destination is the cross-source calendar. The
  /// timetable is no longer a tab of its own — it is the calendar's first source.
  static const String calendar = '/calendar';

  static const String canteen = '/canteen';

  static const String contacts = '/contacts';
  static const String contactAreaName = 'contact-area';
  static const String contactAreaPath = ':slug';

  /// "Mehr" is the fifth top-level destination. Settings and the student email
  /// client both live underneath it — neither is a tab of its own.
  static const String more = '/more';

  // Student email client, nested under More.
  static const String mail = '/more/mail';
  static const String mailSearch = '/more/mail/search';
  static const String mailCompose = '/more/mail/compose';
  static const String mailMessageName = 'mail-message';
  static const String mailMessage = '/more/mail/message/:id';

  // Student grades (HIS-QIS), nested under More.
  static const String grades = '/more/grades';

  // Moodle (direct integration), nested under More.
  static const String moodle = '/more/moodle';
  static const String moodleCourseName = 'moodle-course';
  static const String moodleCoursePath = 'course/:id';

  // Settings is a sub-page of More.
  static const String settings = '/more/settings';
  static const String about = '/more/settings/about';
  static const String imprint = '/more/settings/imprint';
  static const String privacy = '/more/settings/privacy';
  static const String channels = '/more/settings/channels';
}
