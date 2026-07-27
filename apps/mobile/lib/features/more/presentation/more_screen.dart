// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';

/// The "Mehr" section: a small hub that gathers everything that is not one of
/// the four primary tabs. Settings and the student email client live here.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.alternate_email_outlined),
            title: Text(l10n.moreMail),
            subtitle: Text(l10n.moreMailSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.mail),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(l10n.moreGrades),
            subtitle: Text(l10n.moreGradesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.grades),
          ),
          ListTile(
            leading: const Icon(Icons.cast_for_education_outlined),
            title: Text(l10n.moreMoodle),
            subtitle: Text(l10n.moreMoodleSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.moodle),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: Text(l10n.moreTodos),
            subtitle: Text(l10n.moreTodosSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.todos),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.moreSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
