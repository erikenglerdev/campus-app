// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/contact_models.dart';
import '../data/contacts_repository.dart';

/// All active contact areas, sorted by the API's ordering.
final FutureProvider<Loaded<List<ContactArea>>> contactAreasProvider =
    FutureProvider<Loaded<List<ContactArea>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref.watch(contactsRepositoryProvider).fetchAreas(locale: locale);
    });

/// One contact area including its description and persons.
final contactAreaProvider = FutureProvider.family<Loaded<ContactArea>, String>((
  Ref ref,
  String slug,
) async {
  final String locale = ref.watch(localeCodeProvider);
  return ref
      .watch(contactsRepositoryProvider)
      .fetchArea(locale: locale, slug: slug);
});
