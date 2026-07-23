// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import '../application/mail_folders.dart';
import '../application/mail_inbox_controller.dart';
import '../application/mail_sync_controller.dart';
import '../domain/mail_folder.dart';
import '../domain/mail_message.dart';
import 'mail_error_messages.dart';
import 'mail_folder_labels.dart';
import 'mail_folder_picker.dart';
import 'mail_header_tile.dart';

/// Shows the newest headers of the selected mailbox. The INBOX comes from the
/// offline cache and is kept fresh by the background sync; a manual sync button
/// and pull-to-refresh are also available.
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
    final MailFolder folder = ref.watch(selectedMailboxProvider);
    final String? email = ref
        .watch(mailAccountControllerProvider)
        .value
        ?.emailAddress;
    // Shows sync progress; the periodic/app-start scheduling itself lives in the
    // app shell.
    final MailSyncStatus sync = ref.watch(mailSyncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(folderLabel(l10n, folder)),
        actions: <Widget>[
          IconButton(
            onPressed: sync.isSyncing
                ? null
                : () =>
                      ref.read(mailInboxControllerProvider.notifier).refresh(),
            tooltip: l10n.mailSync,
            icon: sync.isSyncing
                ? const SizedBox(
                    height: AppSizes.icon,
                    width: AppSizes.icon,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.mailSearch),
            tooltip: l10n.mailSearchTooltip,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => showMailFolderPicker(context),
            tooltip: l10n.mailFoldersTooltip,
            icon: const Icon(Icons.folder_outlined),
          ),
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
            // First run: the cache is empty while the initial sync is still
            // fetching. Show progress rather than a misleading "no messages".
            if (folder.isInbox && sync.isSyncing) {
              return const LoadingView();
            }
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(mailInboxControllerProvider.notifier).refresh(),
              child: ListView(
                children: <Widget>[
                  const SizedBox(height: AppSpacing.xxxl),
                  EmptyView(
                    title: folderLabel(l10n, folder),
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
                return MailHeaderTile(header: header, locale: locale);
              },
            ),
          );
        },
      ),
    );
  }
}
