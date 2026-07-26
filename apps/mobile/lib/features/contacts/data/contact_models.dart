// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import '../../../core/content/content_block.dart';
import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/json.dart';

/// A contact person inside an area.
///
/// Every field except [name] is optional. Missing fields are **hidden** by the
/// UI, never rendered as an empty row.
class ContactPerson {
  const ContactPerson({
    required this.name,
    this.role,
    this.description,
    this.email,
    this.phone,
    this.website,
    this.profileImageUrl,
  });

  final String name;
  final String? role;
  final String? description;
  final String? email;
  final String? phone;
  final String? website;
  final String? profileImageUrl;

  static ContactPerson? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? name = asString(map['name']);
    if (name == null) return null;
    final String? website = asString(map['website']);
    final Map<String, dynamic>? image = asJsonMap(map['profileImage']);
    final String? imageUrl = asString(image?['url']);
    return ContactPerson(
      name: name,
      role: asString(map['role']),
      description: asString(map['description']),
      email: asString(map['email']),
      phone: asString(map['phone']),
      website: SafeLinkLauncher.isAllowed(website) ? website : null,
      profileImageUrl: SafeLinkLauncher.isAllowed(imageUrl) ? imageUrl : null,
    );
  }
}

/// A contact area. An area **without** any person is valid and must stay fully
/// usable — that is an explicit product requirement, not an edge case.
class ContactArea {
  const ContactArea({
    required this.slug,
    required this.name,
    required this.sortOrder,
    this.shortDescription,
    this.iconKey,
    this.generalEmail,
    this.phone,
    this.website,
    this.appointmentUrl,
    this.address,
    this.openingHours,
    this.personCount = 0,
    this.isDemoContent = false,
    this.description = const <ContentBlock>[],
    this.persons = const <ContactPerson>[],
  });

  final String slug;
  final String name;
  final String? shortDescription;
  final String? iconKey;
  final int sortOrder;

  final String? generalEmail;
  final String? phone;
  final String? website;
  final String? appointmentUrl;
  final String? address;
  final String? openingHours;

  /// Only meaningful on the list endpoint.
  final int personCount;

  /// `true` marks provisional seed data that has not been approved yet.
  final bool isDemoContent;

  final List<ContentBlock> description;
  final List<ContactPerson> persons;

  /// Whether any general contact channel is maintained at all.
  bool get hasContactDetails =>
      generalEmail != null ||
      phone != null ||
      website != null ||
      appointmentUrl != null ||
      address != null ||
      openingHours != null;

  static ContactArea? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    if (slug == null) return null;
    final String? website = asString(map['website']);
    final String? appointmentUrl = asString(map['appointmentUrl']);
    final List<ContactPerson> persons = asList(map['persons'])
        .map(ContactPerson.fromJson)
        .whereType<ContactPerson>()
        .toList(growable: false);
    return ContactArea(
      slug: slug,
      name: asString(map['name']) ?? slug,
      shortDescription: asString(map['shortDescription']),
      iconKey: asString(map['iconKey']),
      sortOrder: asInt(map['sortOrder']) ?? 0,
      generalEmail: asString(map['generalEmail']),
      phone: asString(map['phone']),
      website: SafeLinkLauncher.isAllowed(website) ? website : null,
      appointmentUrl: SafeLinkLauncher.isAllowed(appointmentUrl)
          ? appointmentUrl
          : null,
      address: asString(map['address']),
      openingHours: asString(map['openingHours']),
      personCount: asInt(map['personCount']) ?? persons.length,
      isDemoContent: asBool(map['isDemoContent']) ?? false,
      description: ContentBlock.parse(map['description']),
      persons: persons,
    );
  }

  static List<ContactArea> listFromJson(Object? json) =>
      asList(json).map(ContactArea.fromJson).whereType<ContactArea>().toList()
        ..sort((ContactArea a, ContactArea b) {
          final int order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.name.compareTo(b.name);
        });
}
