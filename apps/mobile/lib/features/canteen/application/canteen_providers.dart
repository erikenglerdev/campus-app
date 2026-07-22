// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/canteen_models.dart';
import '../data/canteen_repository.dart';

/// The canteen list. Comes exclusively from the API.
final FutureProvider<Loaded<List<Canteen>>> canteensProvider =
    FutureProvider<Loaded<List<Canteen>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref.watch(canteenRepositoryProvider).fetchCanteens(locale: locale);
    });

/// The canteen currently shown: the stored preference if it still exists,
/// otherwise the first canteen the API offers.
final Provider<String?> selectedCanteenSlugProvider = Provider<String?>((
  Ref ref,
) {
  final List<Canteen> canteens =
      ref.watch(canteensProvider).value?.value ?? const <Canteen>[];
  if (canteens.isEmpty) return null;
  final String? preferred = ref.watch(
    settingsProvider.select(
      (AppSettings settings) => settings.preferredCanteenSlug,
    ),
  );
  final bool preferredExists = canteens.any(
    (Canteen canteen) => canteen.slug == preferred,
  );
  return preferredExists ? preferred : canteens.first.slug;
});

/// The menu of one canteen for the cached two-week window.
final canteenMenuProvider = FutureProvider.family<Loaded<CanteenMenu>, String>((
  Ref ref,
  String slug,
) async {
  final String locale = ref.watch(localeCodeProvider);
  return ref.watch(canteenRepositoryProvider).fetchMenu(
    locale: locale,
    slug: slug,
  );
});

/// The day the canteen screen currently shows. Defaults to today.
class SelectedMenuDayController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void shiftBy(int days) => select(state.add(Duration(days: days)));
}

final NotifierProvider<SelectedMenuDayController, DateTime>
selectedMenuDayProvider =
    NotifierProvider<SelectedMenuDayController, DateTime>(
      SelectedMenuDayController.new,
    );
