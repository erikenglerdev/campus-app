// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:meta/meta.dart';

import '../../../core/network/json.dart';

/// A public calendar as delivered by `GET /v1/calendars`.
///
/// Purely public campus data from the Campus API. The Google calendar id and
/// ICS feed URL are backend-internal and never present; the only Google link is
/// the ready-made [googleOpenUrl].
@immutable
class PublicCalendar {
  const PublicCalendar({
    required this.id,
    required this.slug,
    required this.name,
    required this.colorHex,
    required this.iconKey,
    required this.sortOrder,
    required this.defaultSubscribed,
    required this.googleOpenUrl,
    this.description,
    this.attribution,
    this.dataStale = false,
    this.lastSuccessfulSyncAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String colorHex;
  final String iconKey;
  final int sortOrder;
  final bool defaultSubscribed;
  final String? attribution;
  final bool dataStale;
  final DateTime? lastSuccessfulSyncAt;
  final String googleOpenUrl;

  static PublicCalendar? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    final String? id = asString(map['id']);
    final String? name = asString(map['name']);
    final String? googleOpenUrl = asString(map['googleOpenUrl']);
    if (slug == null || id == null || name == null || googleOpenUrl == null) {
      return null;
    }
    return PublicCalendar(
      id: id,
      slug: slug,
      name: name,
      description: asString(map['description']),
      colorHex: asString(map['colorHex']) ?? '#5B3FD0',
      iconKey: asString(map['iconKey']) ?? 'calendar',
      sortOrder: asInt(map['sortOrder']) ?? 0,
      defaultSubscribed: asBool(map['defaultSubscribed']) ?? false,
      attribution: asString(map['attribution']),
      dataStale: asBool(map['dataStale']) ?? false,
      lastSuccessfulSyncAt: asDateTime(map['lastSuccessfulSyncAt']),
      googleOpenUrl: googleOpenUrl,
    );
  }

  static List<PublicCalendar> listFromJson(Object? json) => asList(json)
      .map(PublicCalendar.fromJson)
      .whereType<PublicCalendar>()
      .toList(growable: false);
}

/// A single public-calendar event as delivered by the events endpoints.
@immutable
class PublicCalendarEvent {
  const PublicCalendarEvent({
    required this.id,
    required this.calendarId,
    required this.calendarSlug,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.status = 'confirmed',
    this.description,
    this.location,
  });

  final String id;
  final String calendarId;
  final String calendarSlug;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String status;

  static PublicCalendarEvent? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? id = asString(map['id']);
    final String? slug = asString(map['calendarSlug']);
    final DateTime? start = asDateTime(map['start']);
    final DateTime? end = asDateTime(map['end']);
    if (id == null || slug == null || start == null || end == null) return null;
    return PublicCalendarEvent(
      id: id,
      calendarId: asString(map['calendarId']) ?? '',
      calendarSlug: slug,
      title: asString(map['title']) ?? '',
      description: asString(map['description']),
      location: asString(map['location']),
      start: start,
      end: end,
      allDay: asBool(map['allDay']) ?? false,
      status: asString(map['status']) ?? 'confirmed',
    );
  }

  static List<PublicCalendarEvent> listFromJson(Object? json) => asList(json)
      .map(PublicCalendarEvent.fromJson)
      .whereType<PublicCalendarEvent>()
      .toList(growable: false);
}
