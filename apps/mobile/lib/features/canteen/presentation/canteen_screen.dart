// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../../search/presentation/search_screen.dart';
import '../application/canteen_filter_controller.dart';
import '../application/canteen_providers.dart';
import '../domain/canteen_filter.dart';
import 'canteen_filter_sheet.dart';
import '../application/canteen_refresh_scheduler.dart';
import '../data/canteen_models.dart';
import 'canteen_picker_sheet.dart';
import 'meal_card.dart';

/// The canteen screen: canteen picker, day navigation and the meals of the
/// selected day, including every price group.
class CanteenScreen extends ConsumerStatefulWidget {
  const CanteenScreen({super.key});

  @override
  ConsumerState<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends ConsumerState<CanteenScreen>
    with WidgetsBindingObserver {
  late final CanteenRefreshScheduler _scheduler;

  @override
  void initState() {
    super.initState();
    _scheduler = CanteenRefreshScheduler(onRefresh: _refresh);
    WidgetsBinding.instance.addObserver(this);
    _scheduler.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduler.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _scheduler.handleLifecycleState(state);
  }

  Future<void> _refresh() async {
    ref.invalidate(canteensProvider);
    final String? slug = ref.read(selectedCanteenSlugProvider);
    if (slug != null) ref.invalidate(canteenMenuProvider(slug));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<Canteen>>> canteens = ref.watch(
      canteensProvider,
    );
    final String? slug = ref.watch(selectedCanteenSlugProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.canteenTitle),
        actions: <Widget>[
          const SearchIconButton(),
          IconButton(
            tooltip: l10n.canteenPickerTooltip,
            onPressed: () => showCanteenPickerSheet(context),
            icon: const Icon(Icons.restaurant_outlined),
          ),
        ],
      ),
      body: switch (canteens) {
        AsyncLoading<Loaded<List<Canteen>>>() when !canteens.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<List<Canteen>>>(:final Object error) => ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(canteensProvider),
        ),
        _ when slug == null => EmptyView(
          icon: Icons.restaurant_outlined,
          title: l10n.canteenNoCanteensTitle,
          message: l10n.canteenNoCanteensMessage,
        ),
        _ => _MenuBody(slug: slug, onRefresh: _refresh),
      },
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({required this.slug, required this.onRefresh});

  final String slug;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Loaded<CanteenMenu>> menu = ref.watch(
      canteenMenuProvider(slug),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: switch (menu) {
        AsyncLoading<Loaded<CanteenMenu>>() when !menu.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<CanteenMenu>>(:final Object error) => ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(canteenMenuProvider(slug)),
        ),
        _ => _MenuContent(loaded: menu.requireValue, slug: slug),
      },
    );
  }
}

class _MenuContent extends ConsumerWidget {
  const _MenuContent({required this.loaded, required this.slug});

  final Loaded<CanteenMenu> loaded;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime selectedDay = ref.watch(selectedMenuDayProvider);
    final CanteenMenu menu = loaded.value;
    final MenuDay? day = menu.dayFor(selectedDay);
    final List<Meal> allMeals = day?.meals ?? const <Meal>[];
    final CanteenFilter filter = ref.watch(canteenFilterProvider);
    final List<Meal> meals = filter.apply(allMeals);
    final int hiddenCount = allMeals.where(filter.isHidden).length;

    // The filter offers only what the source published for the visible day —
    // never a fixed vocabulary the data may not support.
    final Map<String, MealMarker> markerVocabulary = <String, MealMarker>{
      for (final Meal meal in allMeals)
        for (final MealMarker marker in meal.markers) marker.code: marker,
    };
    final Map<String, MealPrice> priceVocabulary = <String, MealPrice>{
      for (final Meal meal in allMeals)
        for (final MealPrice price in meal.prices) price.group: price,
    };

    final DateTime? lastSync = loaded.meta.lastSuccessfulSyncAt;
    final bool stale = loaded.meta.dataStale;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            menu.campusLabel == null
                ? menu.displayName
                : '${menu.displayName} · ${menu.campusLabel}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DayNavigator(date: selectedDay),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => showCanteenFilterSheet(
                context,
                markerVocabulary.values.toList(growable: false),
                priceVocabulary.values.toList(growable: false),
              ),
              icon: const Icon(Icons.tune, size: AppSizes.iconSmall),
              label: Text(
                filter.isActive
                    ? l10n.canteenFilterActive
                    : l10n.canteenFilterTitle,
              ),
            ),
            if (hiddenCount > 0) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  l10n.canteenHiddenCount(hiddenCount),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (loaded.fromCache) ...<Widget>[
          OfflineNotice(cachedAt: loaded.cachedAt),
          const SizedBox(height: AppSpacing.md),
        ],
        if (stale) ...<Widget>[
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.update_disabled_outlined,
            title: l10n.canteenStaleTitle,
            message: l10n.canteenStaleMessage,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          lastSync == null
              ? l10n.canteenNeverSynced
              : l10n.canteenLastSyncAt(
                  AppDateFormats.dateTime(lastSync, locale),
                ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        // "Nothing on offer" and "nothing matches your filter" are different
        // answers, and only the second one has an obvious remedy.
        if (meals.isEmpty && allMeals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: EmptyView(
              icon: Icons.filter_alt_off_outlined,
              title: l10n.canteenNoMealsAfterFilter,
              message: l10n.canteenFilterMarkersHint,
              action: FilledButton.icon(
                onPressed: () =>
                    ref.read(canteenFilterProvider.notifier).clear(),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l10n.canteenFilterClear),
              ),
            ),
          )
        else if (meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: EmptyView(
              icon: Icons.no_meals_outlined,
              title: l10n.canteenNoMealsTitle,
              message: l10n.canteenNoMealsMessage,
            ),
          )
        else
          for (final Meal meal in meals) ...<Widget>[
            MealCard(
              meal: meal,
              isFavourite: filter.isFavourite(meal),
              emphasisedPriceGroup: filter.priceGroup,
              onToggleFavourite: () => ref
                  .read(canteenFilterProvider.notifier)
                  .toggleFavourite(meal),
              onHide: () =>
                  ref.read(canteenFilterProvider.notifier).toggleHidden(meal),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        if (meals.any((Meal meal) => meal.sourceLanguage == 'de'))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.canteenSourceLanguageHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _DayNavigator extends ConsumerWidget {
  const _DayNavigator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: l10n.canteenPreviousDay,
          onPressed: () =>
              ref.read(selectedMenuDayProvider.notifier).shiftBy(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.canteenDayLabel(AppDateFormats.weekdayDate(date, locale)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.canteenNextDay,
          onPressed: () =>
              ref.read(selectedMenuDayProvider.notifier).shiftBy(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
