// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../l10n/l10n.dart';
import '../domain/grade.dart';
import 'grade_messages.dart';

/// An icon + colour for a status, so it is never distinguished by colour alone.
({IconData icon, Color color}) _statusVisual(
  BuildContext context,
  ExamStatus s,
) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (s) {
    ExamStatus.passed => (
      icon: Icons.check_circle_outline,
      color: scheme.primary,
    ),
    ExamStatus.failed => (icon: Icons.cancel_outlined, color: scheme.error),
    ExamStatus.present => (
      icon: Icons.schedule_outlined,
      color: scheme.tertiary,
    ),
    ExamStatus.unknown => (
      icon: Icons.help_outline,
      color: scheme.onSurfaceVariant,
    ),
  };
}

/// One exam row in the grades list.
class GradeTile extends StatelessWidget {
  const GradeTile({required this.entry, required this.onTap, super.key});

  final GradeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final TextTheme text = Theme.of(context).textTheme;
    final ({IconData icon, Color color}) visual = _statusVisual(
      context,
      entry.status,
    );

    final String subtitle = <String>[
      statusLabel(l10n, entry),
      if (entry.examDate != null)
        AppDateFormats.longDate(entry.examDate!, locale),
    ].join(' · ');

    return Semantics(
      button: true,
      label:
          '${entry.title}, ${statusLabel(l10n, entry)}, '
          '${gradeText(l10n, locale, entry.grade)}',
      child: ListTile(
        leading: Icon(visual.icon, color: visual.color),
        title: Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge,
        ),
        subtitle: Text(subtitle, style: text.bodySmall),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            gradeText(l10n, locale, entry.grade),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: entry.grade.isGraded ? visual.color : null,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
