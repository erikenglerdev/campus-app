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
import '../application/canteen_providers.dart';
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
    final List<Meal> meals = day?.meals ?? const <Meal>[];

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
        if (meals.isEmpty)
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
            MealCard(meal: meal),
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
