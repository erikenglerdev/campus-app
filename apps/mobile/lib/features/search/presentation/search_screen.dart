// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_density.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/search_providers.dart';
import '../domain/search_result.dart';

/// Global search over public content.
///
/// The search bar lives **here**, on a screen you open — not permanently at the
/// top of every list. A bar that is always visible costs a row of screen on
/// every scroll for something used occasionally; a compact icon costs nothing.
///
/// Matching is synchronous over already-cached data, so results appear as fast
/// as the keystroke and nothing is sent anywhere.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l10n, SearchCategory category) =>
      switch (category) {
        SearchCategory.section => l10n.searchCategorySection,
        SearchCategory.news => l10n.searchCategoryNews,
        SearchCategory.event => l10n.searchCategoryEvent,
        SearchCategory.timetable => l10n.searchCategoryTimetable,
        SearchCategory.room => l10n.searchCategoryRoom,
        SearchCategory.contact => l10n.searchCategoryContact,
        SearchCategory.meal => l10n.searchCategoryMeal,
      };

  IconData _categoryIcon(SearchCategory category) => switch (category) {
    SearchCategory.section => Icons.apps_outlined,
    SearchCategory.news => Icons.article_outlined,
    SearchCategory.event => Icons.event_outlined,
    SearchCategory.timetable => Icons.schedule_outlined,
    SearchCategory.room => Icons.meeting_room_outlined,
    SearchCategory.contact => Icons.contact_support_outlined,
    SearchCategory.meal => Icons.restaurant_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final String query = ref.watch(searchQueryProvider);
    final List<SearchResult> results = ref.watch(searchResultsProvider);

    // Grouped by category, preserving the ranked order inside each group.
    final Map<SearchCategory, List<SearchResult>> grouped =
        <SearchCategory, List<SearchResult>>{};
    for (final SearchResult result in results) {
      grouped.putIfAbsent(result.category, () => <SearchResult>[]).add(result);
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            // No visible label, so the hint is also the accessible name.
            hintText: l10n.searchHint,
          ),
          onChanged: (String value) =>
              ref.read(searchQueryProvider.notifier).set(value),
        ),
        actions: <Widget>[
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l10n.searchClear,
              onPressed: () {
                _controller.clear();
                ref.read(searchQueryProvider.notifier).clear();
                _focus.requestFocus();
              },
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(metrics.screenPadding),
        children: <Widget>[
          // Said on the screen itself, not only in a privacy page: a user has
          // to be able to tell what this search does and does not reach.
          Text(
            l10n.searchScopeHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: metrics.sectionGap),

          if (query.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: EmptyView(
                icon: Icons.search,
                title: l10n.searchStartTyping,
                message: l10n.searchHint,
              ),
            )
          else if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: EmptyView(
                icon: Icons.search_off,
                title: l10n.searchNoResults,
                message: l10n.searchNoResultsHint,
              ),
            )
          else ...<Widget>[
            Text(
              l10n.searchResultCount(results.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final MapEntry<SearchCategory, List<SearchResult>> group
                in grouped.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    _categoryLabel(l10n, group.key),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              for (final SearchResult result in group.value)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_categoryIcon(result.category)),
                  title: Text(result.title),
                  subtitle: result.subtitle == null
                      ? null
                      : Text(
                          result.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  // The category is part of the accessible name, so a screen
                  // reader knows what kind of thing it just landed on.
                  onTap: () => GoRouter.of(context).go(result.route),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The compact entry point.
///
/// One widget so every screen offering search looks and behaves identically —
/// and so there is exactly one place to change if it ever moves.
class SearchIconButton extends ConsumerWidget {
  const SearchIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: l10n.searchTooltip,
      onPressed: () {
        ref.read(searchQueryProvider.notifier).clear();
        GoRouter.of(context).push(AppRoutes.search);
      },
    );
  }
}
