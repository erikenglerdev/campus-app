// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/timetable_providers.dart';
import '../data/timetable_models.dart';

/// Opens the course picker as a modal bottom sheet.
///
/// The sheet is scroll controlled because the API delivers the full group list
/// (roughly 270 entries) in one response; the search narrows it down locally,
/// which also keeps working offline.
Future<void> showTimetableGroupPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: const SafeArea(child: TimetableGroupPickerList()),
    ),
  );
}

/// Searchable list of all study groups. Exactly one group can be selected.
class TimetableGroupPickerList extends ConsumerStatefulWidget {
  const TimetableGroupPickerList({super.key});

  @override
  ConsumerState<TimetableGroupPickerList> createState() =>
      _TimetableGroupPickerListState();
}

class _TimetableGroupPickerListState
    extends ConsumerState<TimetableGroupPickerList> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<TimetableGroup>>> groups = ref.watch(
      timetableGroupsProvider,
    );
    final String? selected = ref.watch(selectedTimetableGroupIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.timetableGroupPickerTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (String _) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.timetableGroupSearchLabel,
              hintText: l10n.timetableGroupSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: switch (groups) {
            AsyncLoading<Loaded<List<TimetableGroup>>>() when !groups.hasValue =>
              const LoadingView(),
            AsyncError<Loaded<List<TimetableGroup>>>(:final Object error) =>
              ErrorView(
                failure: error,
                onRetry: () => ref.invalidate(timetableGroupsProvider),
              ),
            _ => _buildList(l10n, groups.requireValue.value, selected),
          },
        ),
      ],
    );
  }

  Widget _buildList(
    AppLocalizations l10n,
    List<TimetableGroup> groups,
    String? selected,
  ) {
    if (groups.isEmpty) {
      return EmptyView(
        icon: Icons.school_outlined,
        title: l10n.timetableNoGroupsTitle,
        message: l10n.timetableNoGroupsMessage,
      );
    }

    final List<TimetableGroup> matches = groups
        .where((TimetableGroup group) => group.matches(_search.text))
        .toList(growable: false);

    if (matches.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_outlined,
        title: l10n.timetableGroupSearchEmptyTitle,
        message: l10n.timetableGroupSearchEmptyMessage,
      );
    }

    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (String? value) async {
        await ref.read(settingsProvider.notifier).setTimetableGroup(value);
        if (mounted) await Navigator.of(context).maybePop();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: matches.length,
        itemBuilder: (BuildContext context, int index) {
          final TimetableGroup group = matches[index];
          return RadioListTile<String>.adaptive(
            value: group.id,
            title: Text(group.shortName),
            subtitle: _subtitle(group),
          );
        },
      ),
    );
  }

  /// Long name and department, both verbatim from the source system.
  Widget? _subtitle(TimetableGroup group) {
    final List<String> parts = <String?>[
      group.longName,
      group.department,
    ].whereType<String>().toList(growable: false);
    if (parts.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[for (final String part in parts) Text(part)],
    );
  }
}
