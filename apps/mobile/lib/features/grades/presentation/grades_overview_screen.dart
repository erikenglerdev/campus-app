// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/grade_account_controller.dart';
import '../application/grades_controller.dart';
import '../domain/grade.dart';
import '../domain/grade_failure.dart';
import 'grade_detail_sheet.dart';
import 'grade_messages.dart';
import 'grade_tile.dart';

/// Shows the cached Notenspiegel with a "last updated" line, a manual refresh,
/// and — on a failed refresh — a banner while keeping the last good data visible.
class GradesOverviewScreen extends ConsumerStatefulWidget {
  const GradesOverviewScreen({super.key});

  @override
  ConsumerState<GradesOverviewScreen> createState() =>
      _GradesOverviewScreenState();
}

class _GradesOverviewScreenState extends ConsumerState<GradesOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Lazy automatic sync on open (respects the 24-hour gate internally).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(gradesControllerProvider.notifier).maybeAutoSync(),
    );
  }

  Future<void> _confirmDelete() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.gradesDeleteConfirmTitle),
        content: Text(l10n.gradesDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.gradesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.gradesDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(gradeAccountControllerProvider.notifier)
          .deleteEverything();
    }
  }

  List<GradeEntry> _sorted(List<GradeEntry> entries) {
    final List<GradeEntry> sorted = List<GradeEntry>.of(entries);
    sorted.sort((GradeEntry a, GradeEntry b) {
      final DateTime? da = a.examDate;
      final DateTime? db = b.examDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1; // undated rows sink to the end, never lost
      if (db == null) return -1;
      return db.compareTo(da); // newest first
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final GradesViewState view =
        ref.watch(gradesControllerProvider).value ?? const GradesViewState();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gradesTitle),
        actions: <Widget>[
          IconButton(
            onPressed: view.isSyncing
                ? null
                : () => ref.read(gradesControllerProvider.notifier).refresh(),
            tooltip: l10n.gradesRefresh,
            icon: view.isSyncing
                ? const SizedBox(
                    height: AppSizes.icon,
                    width: AppSizes.icon,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'delete') _confirmDelete();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(l10n.gradesDeleteAction),
              ),
            ],
          ),
        ],
      ),
      body: _body(context, l10n, locale, view),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    GradesViewState view,
  ) {
    if (view.report == null) {
      if (view.isSyncing) {
        return Semantics(
          liveRegion: true,
          label: l10n.gradesSyncing,
          child: const LoadingView(),
        );
      }
      final GradeFailure? error = view.error;
      if (error != null) {
        final bool invalid = error.kind == GradeFailureKind.invalidCredentials;
        return EmptyView(
          icon: Icons.error_outline,
          title: l10n.errorGenericTitle,
          message: gradeFailureMessage(l10n, error),
          action: FilledButton.icon(
            onPressed: invalid
                ? () => ref
                      .read(gradeAccountControllerProvider.notifier)
                      .deleteEverything()
                : () => ref.read(gradesControllerProvider.notifier).refresh(),
            icon: Icon(invalid ? Icons.login : Icons.refresh),
            label: Text(invalid ? l10n.gradesReenter : l10n.gradesRetry),
          ),
        );
      }
      return EmptyView(title: l10n.gradesTitle, message: l10n.gradesEmpty);
    }

    final List<GradeEntry> entries = _sorted(view.report!.entries);
    return RefreshIndicator(
      onRefresh: () => ref.read(gradesControllerProvider.notifier).refresh(),
      child: ListView(
        children: <Widget>[
          _Header(view: view, locale: locale),
          if (view.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: StatusBanner(
                tone: StatusTone.warning,
                icon: Icons.sync_problem,
                title: l10n.gradesUpdateFailed,
                message: gradeFailureMessage(l10n, view.error),
              ),
            ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(l10n.gradesEmpty),
            )
          else
            for (final GradeEntry entry in entries) ...<Widget>[
              GradeTile(
                entry: entry,
                onTap: () => showGradeDetailSheet(context, entry),
              ),
              const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view, required this.locale});

  final GradesViewState view;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String when = view.lastSuccessfulSync == null
        ? l10n.gradesNeverSynced
        : l10n.gradesLastUpdated(
            AppDateFormats.dateTime(view.lastSuccessfulSync!, locale),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(when, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
