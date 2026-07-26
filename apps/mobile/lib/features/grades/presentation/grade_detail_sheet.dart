// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/grade.dart';
import 'grade_messages.dart';

/// Shows all fields of one exam row in a bottom sheet.
Future<void> showGradeDetailSheet(BuildContext context, GradeEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => _GradeDetailSheet(entry: entry),
  );
}

class _GradeDetailSheet extends StatelessWidget {
  const _GradeDetailSheet({required this.entry});

  final GradeEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final TextTheme text = Theme.of(context).textTheme;

    final List<({String label, String value})> rows =
        <({String label, String value})>[
          (
            label: l10n.gradeFieldGrade,
            value: gradeText(l10n, locale, entry.grade),
          ),
          (label: l10n.gradeFieldStatus, value: statusLabel(l10n, entry)),
          if (entry.examDate != null)
            (
              label: l10n.gradeFieldDate,
              value: AppDateFormats.longDate(entry.examDate!, locale),
            ),
          if (entry.attempt != null)
            (label: l10n.gradeFieldAttempt, value: entry.attempt!),
          if (entry.examNumber.isNotEmpty)
            (label: l10n.gradeFieldExamNumber, value: entry.examNumber),
          if (entry.points != null)
            (label: l10n.gradeFieldPoints, value: entry.points!),
          if (entry.bonus != null)
            (label: l10n.gradeFieldBonus, value: entry.bonus!),
          if (entry.examiner != null && entry.examiner!.isNotEmpty)
            (label: l10n.gradeFieldExaminer, value: entry.examiner!),
        ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.title.isEmpty ? l10n.gradeDetailTitle : entry.title,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final ({String label, String value}) row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 132,
                      child: Text(
                        row.label,
                        style: text.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(row.value, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
