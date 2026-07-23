// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_folder.dart';
import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_folders.dart';
import 'mail_providers.dart';

const int kInboxLimit = 50;

/// Loads the newest [kInboxLimit] headers of the currently selected mailbox on
/// demand.
///
/// No background sync, no IMAP IDLE: the connection is opened, used and closed
/// by the gateway per call. Switching folders or an explicit refresh re-fetches.
class MailInboxController extends AsyncNotifier<List<MailMessageHeader>> {
  @override
  Future<List<MailMessageHeader>> build() async {
    // Rebuild whenever the account or the selected folder changes, but read the
    // resolved account value rather than awaiting `.future`: awaiting another
    // provider's future inside a build that then throws leaves this provider's
    // own future unresolved.
    final account = ref.watch(mailAccountControllerProvider).value;
    if (account == null || !account.isSignedIn) {
      return const <MailMessageHeader>[];
    }
    final MailFolder folder = ref.watch(selectedMailboxProvider);
    final credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    return ref
        .read(mailGatewayProvider)
        .fetchHeaders(
          credentials,
          mailboxPath: folder.path,
          limit: kInboxLimit,
        );
  }

  Future<void> refresh() async {
    final MailFolder folder = ref.read(selectedMailboxProvider);
    state = const AsyncLoading<List<MailMessageHeader>>();
    state = await AsyncValue.guard(() async {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      return ref
          .read(mailGatewayProvider)
          .fetchHeaders(
            credentials,
            mailboxPath: folder.path,
            limit: kInboxLimit,
          );
    });
  }
}

final AsyncNotifierProvider<MailInboxController, List<MailMessageHeader>>
mailInboxControllerProvider =
    AsyncNotifierProvider<MailInboxController, List<MailMessageHeader>>(
      MailInboxController.new,
      // No silent auto-retry: a failed fetch (timeout, TLS, auth) must surface
      // to the user as an error they can retry by pulling to refresh, not spin
      // in Riverpod's default exponential backoff for minutes.
      retry: (_, _) => null,
    );

/// Identifies one message: its mailbox path and its per-mailbox id (UID).
typedef MailMessageRef = ({String mailboxPath, String id});

/// One message detail. Marks the message \Seen after a successful load.
final mailMessageProvider =
    FutureProvider.family<MailMessageDetail, MailMessageRef>((
      Ref ref,
      MailMessageRef ref_,
    ) async {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      final gateway = ref.read(mailGatewayProvider);
      final detail = await gateway.fetchMessage(
        credentials,
        mailboxPath: ref_.mailboxPath,
        id: ref_.id,
      );
      // Best effort: a failed markSeen must not fail the read.
      try {
        await gateway.markSeen(
          credentials,
          mailboxPath: ref_.mailboxPath,
          id: ref_.id,
        );
      } catch (_) {}
      return detail;
    }, retry: (_, _) => null);
