// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import '../application/mail_inbox_controller.dart';
import '../domain/mail_message.dart';
import 'mail_error_messages.dart';

/// Shows the 50 newest INBOX headers. No background sync, no IDLE: the list is
/// fetched on demand and refreshed only by an explicit pull or retry.
class MailInboxScreen extends ConsumerWidget {
  const MailInboxScreen({super.key});

  Future<void> _confirmRemoveAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.mailAccountRemoveConfirmTitle),
        content: Text(l10n.mailAccountRemoveConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.mailCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mailAccountRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(mailAccountControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final AsyncValue<List<MailMessageHeader>> inbox = ref.watch(
      mailInboxControllerProvider,
    );
    final String? email = ref
        .watch(mailAccountControllerProvider)
        .value
        ?.emailAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mailInboxTitle),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'remove') _confirmRemoveAccount(context, ref);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'remove',
                child: Text(l10n.mailAccountRemove),
              ),
            ],
          ),
        ],
        bottom: email == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.mailSignedInAs(email),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.mailCompose),
        tooltip: l10n.mailComposeTooltip,
        child: const Icon(Icons.edit_outlined),
      ),
      body: inbox.when(
        loading: () => const LoadingView(),
        error: (Object error, _) => EmptyView(
          icon: Icons.error_outline,
          title: l10n.errorGenericTitle,
          message: mailFailureMessage(l10n, error),
          action: FilledButton.icon(
            onPressed: () =>
                ref.read(mailInboxControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.mailRetry),
          ),
        ),
        data: (List<MailMessageHeader> headers) {
          if (headers.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(mailInboxControllerProvider.notifier).refresh(),
              child: ListView(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxxl),
                  EmptyView(
                    title: l10n.mailInboxTitle,
                    message: l10n.mailInboxEmpty,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(mailInboxControllerProvider.notifier).refresh(),
            child: ListView.separated(
              itemCount: headers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final MailMessageHeader header = headers[index];
                return _MailHeaderTile(header: header, locale: locale);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MailHeaderTile extends StatelessWidget {
  const _MailHeaderTile({required this.header, required this.locale});

  final MailMessageHeader header;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final FontWeight weight = header.isSeen
        ? FontWeight.normal
        : FontWeight.w700;
    final String sender = header.from.display.trim().isEmpty
        ? l10n.mailUnknownSender
        : header.from.display;
    final String subject = header.subject.trim().isEmpty
        ? l10n.mailNoSubject
        : header.subject;

    return ListTile(
      leading: header.isSeen
          ? const Icon(Icons.mail_outline)
          : const Icon(Icons.markunread),
      title: Text(
        sender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge?.copyWith(fontWeight: weight),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: weight),
          ),
          if (header.date != null)
            Text(
              AppDateFormats.dateTime(header.date!, locale),
              style: text.bodySmall,
            ),
        ],
      ),
      trailing: header.hasAttachments
          ? const Icon(Icons.attach_file, size: AppSizes.icon)
          : null,
      isThreeLine: header.date != null,
      onTap: () => context.pushNamed(
        AppRoutes.mailMessageName,
        pathParameters: <String, String>{'id': header.id},
      ),
    );
  }
}
