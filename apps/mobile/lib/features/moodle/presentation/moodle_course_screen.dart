// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/documents/app_document.dart';
import '../../../core/documents/document_viewer_screen.dart';
import '../../../core/links/safe_link_launcher.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/moodle_course_detail.dart';
import '../application/moodle_providers.dart';
import '../domain/moodle_assignment.dart';
import '../domain/moodle_content.dart';
import '../domain/moodle_downloader.dart';
import '../domain/moodle_repository.dart';
import 'moodle_messages.dart';

/// A course detail page with three tabs: contents (sections/modules/files),
/// assignments (with submission status) and announcements — all read-only.
class MoodleCourseScreen extends ConsumerWidget {
  const MoodleCourseScreen({required this.courseId, super.key});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final AsyncValue<MoodleCourseDetail> detail = ref.watch(
      moodleCourseDetailProvider(courseId),
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(detail.value?.course.fullName ?? l10n.moodleTitle),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.moodleRefresh,
              onPressed: () => refreshMoodleCourseDetail(ref, courseId),
              icon: const Icon(Icons.refresh),
            ),
          ],
          // Scrollable, so all three labels stay whole. Three equal thirds of
          // a 320 px phone cannot hold "Ankündigungen" at a large text size,
          // and an abbreviation nobody can decode is worse than a swipe.
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.moodleTabContents),
              Tab(text: l10n.moodleTabAssignments),
              Tab(text: l10n.moodleTabAnnouncements),
            ],
          ),
        ),
        body: detail.when(
          loading: () => const LoadingView(),
          error: (Object error, _) => EmptyView(
            icon: Icons.error_outline,
            title: l10n.errorGenericTitle,
            message: moodleFailureMessage(l10n, error),
            action: FilledButton.icon(
              onPressed: () => refreshMoodleCourseDetail(ref, courseId),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.moodleRefresh),
            ),
          ),
          data: (MoodleCourseDetail d) => TabBarView(
            children: <Widget>[
              _ContentsTab(detail: d),
              _AssignmentsTab(detail: d, locale: locale),
              _AnnouncementsTab(detail: d, locale: locale),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentsTab extends StatelessWidget {
  const _ContentsTab({required this.detail});

  final MoodleCourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<MoodleSection> sections = detail.sections
        .where((MoodleSection s) => s.visible)
        .toList();
    if (sections.isEmpty) {
      return _EmptyTab(message: l10n.moodleNoSections);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: <Widget>[
        for (final MoodleSection section in sections)
          if (section.modules.isNotEmpty) _SectionCard(section: section),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final MoodleSection section;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            section.name.isEmpty ? '—' : section.name,
            style: text.titleMedium,
          ),
        ),
        for (final MoodleModule module in section.modules)
          _ModuleTile(module: module),
        const Divider(height: 1),
      ],
    );
  }
}

class _ModuleTile extends ConsumerWidget {
  const _ModuleTile({required this.module});

  final MoodleModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    if (!module.visible) {
      return ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(module.name),
        subtitle: Text(
          module.availabilityInfo ?? l10n.moodleHiddenModule,
          style: text.bodySmall,
        ),
        enabled: false,
      );
    }

    // A file-bearing module: one tile per file.
    if (module.files.isNotEmpty) {
      return Column(
        children: <Widget>[
          for (final MoodleFile file in module.files)
            _FileTile(module: module, file: file),
        ],
      );
    }

    // An external link module: opened WITHOUT any token.
    if (module.type == MoodleModuleType.url && module.url != null) {
      return ListTile(
        leading: const Icon(Icons.link_outlined),
        title: Text(module.name),
        subtitle: Text(l10n.moodleExternalLinkNotice, style: text.bodySmall),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openExternal(context, ref, module.url!),
      );
    }

    // A description-only module (label/page snippet).
    return ListTile(
      leading: Icon(_iconFor(module.type)),
      title: Text(module.name),
      subtitle: module.description.isEmpty
          ? null
          : Text(module.description, style: text.bodySmall),
    );
  }

  static IconData _iconFor(MoodleModuleType type) => switch (type) {
    MoodleModuleType.forum => Icons.forum_outlined,
    MoodleModuleType.quiz => Icons.quiz_outlined,
    MoodleModuleType.assign => Icons.assignment_outlined,
    MoodleModuleType.folder => Icons.folder_outlined,
    MoodleModuleType.page => Icons.article_outlined,
    MoodleModuleType.label => Icons.label_outline,
    _ => Icons.circle_outlined,
  };

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (result != LinkLaunchResult.opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.moodleOpenLinkFailed)),
      );
    }
  }
}

/// A single downloadable file. Downloads on tap (never preloaded); a cancel is
/// fired if the tile leaves the tree mid-download so no partial data is kept.
class _FileTile extends ConsumerStatefulWidget {
  const _FileTile({required this.module, required this.file});

  final MoodleModule module;
  final MoodleFile file;

  @override
  ConsumerState<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends ConsumerState<_FileTile> {
  bool _downloading = false;
  MoodleDownloadCancelHandle? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (_downloading) return;
    final AppLocalizations l10n = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final MoodleRepository repo = ref.read(moodleRepositoryProvider);

    final MoodleDownloadCancelHandle cancel = MoodleDownloadCancelHandle();
    setState(() {
      _downloading = true;
      _cancel = cancel;
    });
    try {
      final AppDocument doc = await repo.downloadFile(
        widget.file,
        cancel: cancel.token,
      );
      if (!mounted || cancel.token.isCancelled) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => DocumentViewerScreen(document: doc),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(moodleFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _cancel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int? size = widget.file.fileSize;
    final String subtitle = <String>[
      if (widget.file.mimeType != null) widget.file.mimeType!,
      if (size != null) humanFileSize(size),
    ].join(' · ');

    return ListTile(
      leading: _downloading
          ? const SizedBox(
              height: AppSizes.icon,
              width: AppSizes.icon,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.insert_drive_file_outlined),
      title: Text(widget.file.fileName),
      subtitle: Text(
        _downloading ? l10n.moodleFileDownloading : subtitle,
        style: text.bodySmall,
      ),
      trailing: const Icon(Icons.download_outlined),
      onTap: _open,
    );
  }
}

/// Small owner of a [MoodleDownloadCancel] so the tile can cancel on dispose.
class MoodleDownloadCancelHandle {
  final MoodleDownloadCancel token = MoodleDownloadCancel();
  void cancel() => token.cancel();
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.detail, required this.locale});

  final MoodleCourseDetail detail;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (detail.assignments.isEmpty) {
      return _EmptyTab(message: l10n.moodleNoAssignments);
    }
    final List<MoodleAssignment> items =
        List<MoodleAssignment>.of(detail.assignments)
          ..sort((MoodleAssignment a, MoodleAssignment b) {
            final DateTime? da = a.dueDate;
            final DateTime? db = b.dueDate;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: <Widget>[
        for (final MoodleAssignment a in items)
          _AssignmentTile(assignment: a, locale: locale),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment, required this.locale});

  final MoodleAssignment assignment;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String due = assignment.dueDate == null
        ? l10n.moodleAssignmentNoDue
        : l10n.moodleAssignmentDue(
            AppDateFormats.dateTime(assignment.dueDate!, locale),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(assignment.name, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(due, style: text.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          _SubmissionChips(status: assignment.status),
          const Divider(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SubmissionChips extends StatelessWidget {
  const _SubmissionChips({required this.status});

  final MoodleSubmissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MoodleSubmissionStatus s = status ?? const MoodleSubmissionStatus();
    final String stateLabel = switch (s.state) {
      MoodleSubmissionState.submitted => l10n.moodleSubmissionSubmitted,
      MoodleSubmissionState.draft => l10n.moodleSubmissionDraft,
      MoodleSubmissionState.none => l10n.moodleSubmissionNone,
      MoodleSubmissionState.unknown => l10n.moodleSubmissionUnknown,
    };
    final IconData stateIcon = switch (s.state) {
      MoodleSubmissionState.submitted => Icons.check_circle_outline,
      MoodleSubmissionState.draft => Icons.edit_note_outlined,
      MoodleSubmissionState.none => Icons.radio_button_unchecked,
      MoodleSubmissionState.unknown => Icons.help_outline,
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        // State is conveyed with icon + text, never colour alone.
        Chip(
          avatar: Icon(stateIcon, size: AppSizes.iconSmall),
          label: Text(stateLabel),
          visualDensity: VisualDensity.compact,
        ),
        if (s.isLate)
          Chip(
            avatar: const Icon(
              Icons.warning_amber_outlined,
              size: AppSizes.iconSmall,
            ),
            label: Text(l10n.moodleSubmissionLate),
            visualDensity: VisualDensity.compact,
          ),
        if (s.graded && s.gradeText != null)
          Chip(
            avatar: const Icon(Icons.grade_outlined, size: AppSizes.iconSmall),
            label: Text(l10n.moodleSubmissionGraded(s.gradeText!)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({required this.detail, required this.locale});

  final MoodleCourseDetail detail;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    if (detail.announcements.isEmpty) {
      return _EmptyTab(message: l10n.moodleNoAnnouncements);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: <Widget>[
        for (final announcement in detail.announcements)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(announcement.subject, style: text.titleSmall),
                if (announcement.createdAt != null)
                  Text(
                    AppDateFormats.dateTime(announcement.createdAt!, locale),
                    style: text.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.xs),
                if (announcement.message.isNotEmpty)
                  Text(announcement.message, style: text.bodyMedium),
                const Divider(height: AppSpacing.lg),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
