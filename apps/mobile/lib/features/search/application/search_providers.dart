// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_sections.dart';
import '../../../core/network/loaded.dart';
import '../../../l10n/l10n.dart';
import '../../campusmap/application/campus_map_providers.dart';
import '../../campusmap/domain/room.dart';
import '../../canteen/application/canteen_providers.dart';
import '../../canteen/data/canteen_models.dart';
import '../../contacts/application/contacts_providers.dart';
import '../../contacts/data/contact_models.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_entry.dart';
import '../../news/application/news_providers.dart';
import '../../news/data/news_models.dart';
import '../domain/search_index.dart';
import '../domain/search_result.dart';

/// Builds the search index from **public, already-cached** content.
///
/// ## Why this is client-side and talks to no search endpoint
///
/// Every source below is data the app has already fetched and cached for its
/// own screens: rooms, contacts, news, the two-week menu, the app's own areas.
/// Searching them locally is instant, works offline and — decisively — sends
/// nothing anywhere. A server-side search would mean transmitting every
/// keystroke a student types, which is both unnecessary and the one thing the
/// product rules forbid.
///
/// ## Why mail, grades and Moodle cannot appear here
///
/// Not by policy but by construction: this file imports no personal-service
/// library, and [SearchCategory] has no value they could be filed under. A
/// test asserts both, so adding such an import is a failing build rather than
/// a review comment someone might miss.
///
/// Those areas keep their own searches inside their own protected screens.
final Provider<List<SearchEntry>> searchIndexProvider =
    Provider<List<SearchEntry>>((Ref ref) {
      final AppLocalizations l10n = ref.watch(searchLocalizationsProvider);
      final List<SearchEntry> entries = <SearchEntry>[];

      // 1. The app's own areas, so "Mensa" or "Lageplan" jumps straight there.
      for (final AppSection section in AppSection.values) {
        entries.add(
          SearchEntry(
            category: SearchCategory.section,
            title: section.label(l10n),
            route: section.route,
            sortKey: section.label(l10n),
          ),
        );
      }

      // 2. Rooms and buildings from the bundled catalogue plus the API's names.
      final List<Room> rooms =
          ref.watch(roomsProvider).value?.value ?? const <Room>[];
      for (final Room room in rooms) {
        entries.add(
          SearchEntry(
            category: SearchCategory.room,
            title: room.primaryLabel,
            subtitle: '${room.buildingName} · ${room.floorName}',
            route: AppRoutes.campusMapForRoom(room.roomKey),
            // The plain number too, so "b201" finds "B.201".
            keywords: <String>[room.roomNumber, room.buildingName],
            sortKey: room.roomNumber,
          ),
        );
      }

      // 3. Contact areas.
      final List<ContactArea> areas =
          ref.watch(contactAreasProvider).value?.value ?? const <ContactArea>[];
      for (final ContactArea area in areas) {
        entries.add(
          SearchEntry(
            category: SearchCategory.contact,
            title: area.name,
            subtitle: area.shortDescription,
            route: '${AppRoutes.contacts}/${area.slug}',
            sortKey: area.name,
          ),
        );
      }

      // 4. Announcements.
      final Loaded<NewsPage>? news = ref.watch(newsFeedProvider).value;
      for (final NewsArticle article
          in news?.value.articles ?? const <NewsArticle>[]) {
        entries.add(
          SearchEntry(
            category: SearchCategory.news,
            title: article.title,
            subtitle: article.teaser,
            route: '${AppRoutes.news}/${article.slug}',
            sortKey: article.title,
          ),
        );
      }

      // 5. This month's calendar: public events and timetable entries.
      //
      // Both come from the aggregator for *today's* month, which is the window
      // the app has loaded anyway. Moodle deadlines are a source of that
      // aggregator too and are filtered out here: they are personal content,
      // and the public search must not surface them.
      final DateTime today = DateTime.now();
      final CalendarData calendar = ref.watch(
        calendarDataProvider(DateTime(today.year, today.month, today.day)),
      );
      for (final CalendarEntry entry in calendar.entries) {
        final SearchCategory? category = switch (entry.source) {
          CalendarSource.timetable => SearchCategory.timetable,
          CalendarSource.publicCalendar => SearchCategory.event,
          // Deliberately dropped — see above.
          CalendarSource.moodle => null,
        };
        if (category == null) continue;
        entries.add(
          SearchEntry(
            category: category,
            title: entry.title,
            subtitle: entry.location ?? entry.sourceLabel,
            route: AppRoutes.calendar,
            sortKey: entry.start.toIso8601String(),
          ),
        );
      }

      // 6. Meals of the cached menu window.
      final String? canteenSlug = ref.watch(selectedCanteenSlugProvider);
      if (canteenSlug != null) {
        final Loaded<CanteenMenu>? menu = ref
            .watch(canteenMenuProvider(canteenSlug))
            .value;
        final Set<String> seen = <String>{};
        for (final MenuDay day in menu?.value.days ?? const <MenuDay>[]) {
          for (final Meal meal in day.meals) {
            // The same dish appears on several days; one hit is enough.
            if (!seen.add(meal.name)) continue;
            entries.add(
              SearchEntry(
                category: SearchCategory.meal,
                title: meal.name,
                subtitle: meal.subtitle,
                route: AppRoutes.canteen,
                sortKey: meal.name,
              ),
            );
          }
        }
      }

      return List<SearchEntry>.unmodifiable(entries);
    });

/// The localisations the index uses for the app's own area names.
///
/// A provider so the index can be built without a BuildContext and overridden
/// in tests.
final Provider<AppLocalizations> searchLocalizationsProvider =
    Provider<AppLocalizations>((Ref ref) {
      throw UnimplementedError(
        'searchLocalizationsProvider must be overridden with the current '
        'AppLocalizations — the search screen does this from its context.',
      );
    });

/// The current query. Held in a provider so the results survive a rebuild.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
  void clear() => state = '';
}

final NotifierProvider<SearchQueryController, String> searchQueryProvider =
    NotifierProvider<SearchQueryController, String>(SearchQueryController.new);

/// The ranked results for the current query.
final Provider<List<SearchResult>> searchResultsProvider =
    Provider<List<SearchResult>>(
      (Ref ref) => searchEntries(
        ref.watch(searchIndexProvider),
        ref.watch(searchQueryProvider),
      ),
    );
