// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_providers.dart';

const int kInboxLimit = 50;

/// Loads the newest [kInboxLimit] INBOX headers on demand.
///
/// No background sync, no IMAP IDLE: the connection is opened, used and closed
/// by the gateway per call. Refresh is an explicit invalidate.
class MailInboxController extends AsyncNotifier<List<MailMessageHeader>> {
  @override
  Future<List<MailMessageHeader>> build() async {
    // Rebuild whenever the account changes, but read its resolved value rather
    // than awaiting `.future`: awaiting another provider's future inside a build
    // that then throws leaves this provider's own future unresolved.
    final account = ref.watch(mailAccountControllerProvider).value;
    if (account == null || !account.isSignedIn) {
      return const <MailMessageHeader>[];
    }
    final credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    return ref
        .read(mailGatewayProvider)
        .fetchInbox(credentials, limit: kInboxLimit);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<MailMessageHeader>>();
    state = await AsyncValue.guard(() async {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      return ref
          .read(mailGatewayProvider)
          .fetchInbox(credentials, limit: kInboxLimit);
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

/// One message detail. Marks the message \Seen after a successful load.
final mailMessageProvider = FutureProvider.family<MailMessageDetail, String>((
  Ref ref,
  String id,
) async {
  final credentials = await ref
      .read(mailAccountControllerProvider.notifier)
      .requireCredentials();
  final gateway = ref.read(mailGatewayProvider);
  final detail = await gateway.fetchMessage(credentials, id);
  // Best effort: a failed markSeen must not fail the read.
  try {
    await gateway.markSeen(credentials, id);
  } catch (_) {}
  return detail;
}, retry: (_, _) => null);
