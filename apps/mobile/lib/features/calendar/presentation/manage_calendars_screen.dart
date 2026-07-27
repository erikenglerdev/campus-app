// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/hex_color.dart';
import '../../../l10n/l10n.dart';
import '../application/public_calendar_providers.dart';
import '../application/public_calendar_selection.dart';
import '../data/public_calendars_repository.dart';
import '../domain/public_calendar.dart';

/// "Kalender verwalten": activate/deactivate the public calendars (Y of X) and
/// open them in Google Calendar. Timetable/Moodle are shown as sources on the
/// calendar itself; only public Google calendars can be opened in Google.
class ManageCalendarsScreen extends ConsumerWidget {
  const ManageCalendarsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (result != LinkLaunchResult.opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calendarGoogleLinkFailed)),
      );
    }
  }

  Future<void> _openCombined(
    BuildContext context,
    WidgetRef ref,
    List<String> slugs,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String locale = Localizations.localeOf(context).languageCode;
    try {
      final String url = await ref
          .read(publicCalendarsRepositoryProvider)
          .fetchGoogleViewUrl(slugs: slugs, locale: locale);
      final LinkLaunchResult result = await ref
          .read(linkLauncherProvider)
          .open(url);
      if (result != LinkLaunchResult.opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.calendarGoogleLinkFailed)),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calendarGoogleLinkFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<PublicCalendar>>> catalog = ref.watch(
      publicCalendarsCatalogProvider,
    );
    final PublicCalendarSelectionState selection = ref.watch(
      publicCalendarSelectionProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarManageTitle)),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l10n.calendarPublicUnavailable,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (Loaded<List<PublicCalendar>> loaded) {
          final List<PublicCalendar> calendars = loaded.value;
          final List<String> selectedSlugs =
              PublicCalendarSelectionRules.effectiveSelection(
                available: calendars,
                selected: selection.selectedSlugs,
              );
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.calendarSectionPublic,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (calendars.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          l10n.calendarNoPublicCalendars,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final PublicCalendar calendar in calendars)
                        _CalendarTile(
                          calendar: calendar,
                          selected: selection.isSelected(calendar.slug),
                          onChanged: (bool value) => ref
                              .read(publicCalendarSelectionProvider.notifier)
                              .setSelected(calendar.slug, selected: value),
                          onOpen: () =>
                              _open(context, ref, calendar.googleOpenUrl),
                        ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l10n.calendarGoogleCombinedNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: selectedSlugs.isEmpty
                            ? null
                            : () => _openCombined(context, ref, selectedSlugs),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.calendarOpenSelectedInGoogle),
                      ),
                      if (selectedSlugs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            l10n.calendarSelectAtLeastOne,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.calendar,
    required this.selected,
    required this.onChanged,
    required this.onOpen,
  });

  final PublicCalendar calendar;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Color dot =
        parseHexColor(calendar.colorHex) ?? context.colors.primary;
    final List<String> subtitleParts = <String>[
      if (calendar.attribution != null && calendar.attribution!.isNotEmpty)
        calendar.attribution!,
      if (calendar.dataStale) l10n.calendarDataStale,
    ];
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Colour is decorative; the name (title) carries the identity.
          Container(
            width: AppSizes.iconSmall,
            height: AppSizes.iconSmall,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.public_outlined),
        ],
      ),
      title: Text(calendar.name),
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · '), style: text.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: l10n.calendarOpenInGoogle,
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
          ),
          Switch.adaptive(value: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}
