// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// All route paths and names of the app in one place.
abstract final class AppRoutes {
  static const String news = '/news';
  static const String newsDetailName = 'news-detail';
  static const String newsDetailPath = ':slug';

  /// The second top-level destination is the cross-source calendar. The
  /// timetable is no longer a tab of its own — it is the calendar's first source.
  static const String calendar = '/calendar';

  /// "Manage calendars" (Y-of-X public calendar selection + Google buttons).
  static const String calendarManagePath = 'manage';
  static const String calendarManage = '/calendar/manage';

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

  // Local, on-device to-do list, nested under More.
  static const String todosPath = 'todos';
  static const String todos = '/more/todos';

  // Campus map (fictional demo plan), nested under More.
  static const String campusMapPath = 'campus-map';
  static const String campusMap = '/more/campus-map';

  /// Query parameter carrying the room a deep link should focus.
  static const String campusMapRoomParam = 'room';

  /// In-app deep link used by contact details to open the map on one room.
  ///
  /// A query parameter rather than a path segment: the roomKey is optional,
  /// and the map is a perfectly valid destination without one.
  static String campusMapForRoom(String roomKey) =>
      '$campusMap?$campusMapRoomParam=${Uri.encodeQueryComponent(roomKey)}';

  // Settings is a sub-page of More.
  static const String settings = '/more/settings';
  static const String about = '/more/settings/about';
  static const String imprint = '/more/settings/imprint';
  static const String privacy = '/more/settings/privacy';
  static const String channels = '/more/settings/channels';
}
