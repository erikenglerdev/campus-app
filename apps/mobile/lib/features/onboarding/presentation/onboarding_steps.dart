// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_sections.dart';
import '../../../app/navigation_config.dart';
import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../campusmap/application/campus_map_providers.dart';
import '../../campusmap/domain/map_catalog.dart';
import '../../canteen/application/canteen_providers.dart';
import '../../canteen/data/canteen_models.dart';
import '../../settings/presentation/personalisation_tiles.dart';
import '../../timetable/presentation/timetable_group_picker_sheet.dart';

/// The steps of the first-run setup, in order.
enum OnboardingStep { welcome, appearance, campus, content, navigation }

/// Renders one step.
class OnboardingStepView extends StatelessWidget {
  const OnboardingStepView({required this.step, super.key});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (step) {
      OnboardingStep.welcome => _StepScaffold(
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        icon: Icons.waving_hand_outlined,
        children: <Widget>[
          // The independence notice is part of the very first thing a user
          // sees. It is a project rule, not a footnote.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.aboutIndependenceNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      OnboardingStep.appearance => _StepScaffold(
        title: l10n.onboardingAppearanceTitle,
        body: l10n.onboardingAppearanceBody,
        icon: Icons.palette_outlined,
        children: const <Widget>[
          AccentColorTile(),
          DensityTile(),
          ReducedMotionTile(),
        ],
      ),
      OnboardingStep.campus => _StepScaffold(
        title: l10n.onboardingCampusTitle,
        body: l10n.onboardingCampusBody,
        icon: Icons.place_outlined,
        children: const <Widget>[
          _CanteenStep(),
          _DefaultBuildingStep(),
          _TimetableGroupStep(),
        ],
      ),
      OnboardingStep.content => _StepScaffold(
        title: l10n.onboardingContentTitle,
        body: l10n.onboardingContentBody,
        icon: Icons.rss_feed_outlined,
        children: const <Widget>[_ContentLinks()],
      ),
      OnboardingStep.navigation => _StepScaffold(
        title: l10n.onboardingNavigationTitle,
        body: l10n.onboardingNavigationBody,
        icon: Icons.space_dashboard_outlined,
        children: const <Widget>[_NavigationStep()],
      ),
    };
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.body,
    required this.icon,
    required this.children,
  });

  final String title;
  final String body;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: <Widget>[
        Icon(
          icon,
          size: AppSizes.illustrationIcon,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          // headlineSmall, not a display size: a huge heading eats the content
          // it introduces on a 320 px phone.
          child: Text(title, style: text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

/// Preferred canteen. An empty or failing catalogue is stated, never blocking.
class _CanteenStep extends ConsumerWidget {
  const _CanteenStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<Canteen>>> canteens = ref.watch(
      canteensProvider,
    );
    final String? chosen = ref.watch(
      settingsProvider.select((AppSettings s) => s.preferredCanteenSlug),
    );

    return switch (canteens) {
      AsyncError<Loaded<List<Canteen>>>() => _Unavailable(
        label: l10n.settingsPreferredCanteen,
      ),
      AsyncData<Loaded<List<Canteen>>>(:final Loaded<List<Canteen>> value)
          when value.value.isEmpty =>
        _Unavailable(
          label: l10n.settingsPreferredCanteen,
          message: l10n.onboardingNoCanteens,
        ),
      AsyncData<Loaded<List<Canteen>>>(:final Loaded<List<Canteen>> value) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StepLabel(l10n.settingsPreferredCanteen),
            RadioGroup<String>(
              groupValue: chosen,
              onChanged: (String? slug) =>
                  ref.read(settingsProvider.notifier).setPreferredCanteen(slug),
              child: Column(
                children: <Widget>[
                  for (final Canteen canteen in value.value)
                    RadioListTile<String>.adaptive(
                      value: canteen.slug,
                      title: Text(canteen.displayName),
                    ),
                ],
              ),
            ),
          ],
        ),
      _ => const _StepLoading(),
    };
  }
}

/// Default building for the campus map.
class _DefaultBuildingStep extends ConsumerWidget {
  const _DefaultBuildingStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final MapCatalog? map = ref.watch(mapCatalogProvider).value;
    final String? chosen = ref.watch(
      settingsProvider.select((AppSettings s) => s.defaultBuildingKey),
    );
    if (map == null || map.buildings.isEmpty) {
      return _Unavailable(label: l10n.settingsDefaultBuilding);
    }
    final String locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StepLabel(l10n.settingsDefaultBuilding),
        RadioGroup<String>(
          groupValue: chosen,
          onChanged: (String? key) =>
              ref.read(settingsProvider.notifier).setDefaultBuilding(key),
          child: Column(
            children: <Widget>[
              for (final MapBuilding building in map.buildings)
                RadioListTile<String>.adaptive(
                  value: building.buildingKey,
                  title: Text(building.name.resolve(locale)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The timetable group, chosen through the picker the app already has.
class _TimetableGroupStep extends ConsumerWidget {
  const _TimetableGroupStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(l10n.onboardingOpenTimetableGroup),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showTimetableGroupPickerSheet(context),
    );
  }
}

/// News channels and public calendars, through their existing screens.
///
/// Deliberately links rather than re-implements: both pickers already exist,
/// handle their own empty and offline states, and duplicating them inline
/// would mean two versions of the same rules drifting apart.
class _ContentLinks extends StatelessWidget {
  const _ContentLinks();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.rss_feed_outlined),
          title: Text(l10n.onboardingOpenChannels),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => GoRouter.of(context).push(AppRoutes.channels),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.public),
          title: Text(l10n.onboardingOpenCalendars),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => GoRouter.of(context).push(AppRoutes.calendarManage),
        ),
      ],
    );
  }
}

/// The three middle navigation entries, with the same rules as the settings
/// editor: pick exactly three, fixed entries are not on offer.
class _NavigationStep extends ConsumerStatefulWidget {
  const _NavigationStep();

  @override
  ConsumerState<_NavigationStep> createState() => _NavigationStepState();
}

class _NavigationStepState extends ConsumerState<_NavigationStep> {
  List<AppSection>? _draft;

  List<AppSection> get _chosen =>
      _draft ?? ref.read(settingsProvider).navigation.middle;

  void _set(AppSection section, {required bool selected}) {
    final List<AppSection> next = _chosen.toList();
    if (selected) {
      if (next.length >= NavigationConfig.middleSlots) return;
      next.add(section);
    } else {
      next.remove(section);
    }
    setState(() => _draft = next);
    if (next.length == NavigationConfig.middleSlots) {
      ref.read(settingsProvider.notifier).setNavigationMiddle(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSection> chosen = _chosen;
    final bool full = chosen.length >= NavigationConfig.middleSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!full)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.settingsSelectExactlyThree,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final AppSection section in AppSection.configurable)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(section.icon),
            title: Text(section.label(l10n)),
            value: chosen.contains(section),
            onChanged: full && !chosen.contains(section)
                ? null
                : (bool? value) => _set(section, selected: value ?? false),
          ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _StepLoading extends StatelessWidget {
  const _StepLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// A source that cannot be offered right now. Says so and stays out of the way.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.label, this.message});

  final String label;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StepLabel(label),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: AppSizes.iconSmall,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message ?? context.l10n.onboardingSourceUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
