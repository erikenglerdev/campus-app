// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/settings_controller.dart';
import '../domain/mail_folder.dart';
import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_folders.dart';
import 'mail_providers.dart';
import 'mail_sync_controller.dart';

const int kInboxLimit = 50;

/// Provides the message list of the currently selected mailbox.
///
/// The INBOX is served from the offline cache, so it appears instantly and
/// works offline; a background sync (see [MailSyncController]) keeps it fresh
/// and the list rebuilds via [mailCacheRevisionProvider]. Other folders are
/// fetched online on demand — they are not cached.
class MailInboxController extends AsyncNotifier<List<MailMessageHeader>> {
  @override
  Future<List<MailMessageHeader>> build() async {
    final account = ref.watch(mailAccountControllerProvider).value;
    if (account == null || !account.isSignedIn) {
      return const <MailMessageHeader>[];
    }
    final MailFolder folder = ref.watch(selectedMailboxProvider);

    if (folder.isInbox) {
      // Rebuild whenever the cache changes; read from the cache (offline-first).
      ref.watch(mailCacheRevisionProvider);
      return ref.read(mailCacheStoreProvider).readHeaders();
    }

    // Other folders: online, uncached.
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

  /// Manual refresh. For the INBOX this triggers a background sync (which
  /// updates the cache and, in turn, this list); for other folders it re-fetches.
  Future<void> refresh() async {
    final MailFolder folder = ref.read(selectedMailboxProvider);
    if (folder.isInbox) {
      await ref.read(mailSyncControllerProvider.notifier).syncNow();
      return;
    }
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
      // to the user as an error they can retry, not spin in exponential backoff.
      retry: (_, _) => null,
    );

/// Identifies one message: its mailbox path and its per-mailbox id (UID).
typedef MailMessageRef = ({String mailboxPath, String id});

/// One message detail. For the INBOX the cache is consulted first (instant,
/// offline); a cache miss falls back to the network and the result is cached.
/// Marks the message \Seen on the server after a successful load.
final mailMessageProvider =
    FutureProvider.family<MailMessageDetail, MailMessageRef>((
      Ref ref,
      MailMessageRef message,
    ) async {
      final bool isInbox = message.mailboxPath == kInboxPath;
      final cache = ref.read(mailCacheStoreProvider);

      if (isInbox) {
        final MailMessageDetail? cached = await cache.readMessage(message.id);
        if (cached != null) {
          // Best effort: mark seen without blocking the (already available) read.
          unawaited(_markSeen(ref, message));
          return cached;
        }
      }

      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      final gateway = ref.read(mailGatewayProvider);
      final bool downloadAttachments = ref
          .read(settingsProvider)
          .mailDownloadAttachments;
      final detail = await gateway.fetchMessage(
        credentials,
        mailboxPath: message.mailboxPath,
        id: message.id,
        includeAttachmentBytes: downloadAttachments,
      );
      if (isInbox) {
        await cache.saveMessage(detail);
        ref.read(mailCacheRevisionProvider.notifier).bump();
      }
      unawaited(_markSeen(ref, message));
      return detail;
    }, retry: (_, _) => null);

Future<void> _markSeen(Ref ref, MailMessageRef message) async {
  try {
    final credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    await ref
        .read(mailGatewayProvider)
        .markSeen(
          credentials,
          mailboxPath: message.mailboxPath,
          id: message.id,
        );
  } catch (_) {}
}
