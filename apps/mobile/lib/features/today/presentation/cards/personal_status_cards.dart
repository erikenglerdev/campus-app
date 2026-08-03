// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/locale/formatters.dart';
import '../../../../l10n/l10n.dart';
import '../../../grades/application/grade_account_controller.dart';
import '../../../grades/application/grades_controller.dart';
import '../../../mail/application/mail_account_controller.dart';
import '../../../mail/application/mail_inbox_controller.dart';
import '../../../mail/domain/mail_message.dart';
import 'dashboard_section.dart';

/// A discreet mail status.
///
/// A count and a way in — **never** a sender, never a subject line. The
/// dashboard is the screen most likely to be visible to someone standing next
/// to you, and a subject can be as revealing as the message.
///
/// Absent entirely until an account is set up: the dashboard must not advertise
/// a service the user never configured.
class MailStatusCard extends ConsumerWidget {
  const MailStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final MailAccountState? account = ref
        .watch(mailAccountControllerProvider)
        .value;
    if (account == null || !account.isSignedIn) return const SizedBox.shrink();

    final AsyncValue<List<MailMessageHeader>> inbox = ref.watch(
      mailInboxControllerProvider,
    );

    return DashboardSection(
      title: l10n.mailTitle,
      icon: Icons.mail_outline,
      onTap: () => GoRouter.of(context).go(AppRoutes.mail),
      child: switch (inbox) {
        AsyncError<List<MailMessageHeader>>() => const DashboardCardError(),
        AsyncData<List<MailMessageHeader>>(
          :final List<MailMessageHeader> value,
        ) =>
          DashboardLine(
            l10n.todayMailStatusUnread(
              value.where((MailMessageHeader m) => !m.isSeen).length,
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// A discreet grades status.
///
/// States **when** the app last looked, and nothing about what it found. No
/// grade value, no average, no subject — a grade on a lock screen or over a
/// shoulder is exactly the kind of disclosure this app should not cause.
class GradesStatusCard extends ConsumerWidget {
  const GradesStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final GradeAccountState? account = ref
        .watch(gradeAccountControllerProvider)
        .value;
    if (account == null || !account.isSignedIn) return const SizedBox.shrink();

    final GradesViewState? grades = ref.watch(gradesControllerProvider).value;
    final DateTime? lastSync = grades?.lastSuccessfulSync;

    return DashboardSection(
      title: l10n.gradesTitle,
      icon: Icons.grade_outlined,
      onTap: () => GoRouter.of(context).go(AppRoutes.grades),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DashboardLine(
            lastSync == null
                ? l10n.todayGradesNeverChecked
                : l10n.todayGradesChecked(
                    AppDateFormats.dateTime(lastSync, locale),
                  ),
          ),
          const SizedBox(height: 2),
          // Said out loud, so nobody waits for a number that will not come.
          Text(
            l10n.todayGradesPrivacyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
