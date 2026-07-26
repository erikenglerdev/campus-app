// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_folder.dart';
import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_folders.dart';
import 'mail_inbox_controller.dart';
import 'mail_providers.dart';

/// Runs a server-side search over the selected mailbox so it finds messages
/// that are not cached locally, matching the query in the sender and content.
///
/// Search is on demand (an explicit submit), so this is a plain command-style
/// controller rather than a keystroke-driven family. The empty state means
/// "nothing searched yet".
class MailSearchController extends AsyncNotifier<List<MailMessageHeader>> {
  String _query = '';

  /// The query behind the current results (empty before the first search).
  String get query => _query;

  @override
  Future<List<MailMessageHeader>> build() async => const <MailMessageHeader>[];

  /// Runs a search for [rawQuery]. A blank query clears the results.
  Future<void> run(String rawQuery) async {
    final String q = rawQuery.trim();
    _query = q;
    if (q.isEmpty) {
      state = const AsyncData<List<MailMessageHeader>>(<MailMessageHeader>[]);
      return;
    }
    state = const AsyncLoading<List<MailMessageHeader>>();
    state = await AsyncValue.guard(() async {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      final MailFolder folder = ref.read(selectedMailboxProvider);
      return ref
          .read(mailGatewayProvider)
          .searchMessages(
            credentials,
            mailboxPath: folder.path,
            query: q,
            limit: kInboxLimit,
          );
    });
  }

  void clear() {
    _query = '';
    state = const AsyncData<List<MailMessageHeader>>(<MailMessageHeader>[]);
  }
}

final AsyncNotifierProvider<MailSearchController, List<MailMessageHeader>>
mailSearchControllerProvider =
    AsyncNotifierProvider<MailSearchController, List<MailMessageHeader>>(
      MailSearchController.new,
      // A failed search surfaces as an error the user can retry; no backoff spin.
      retry: (_, _) => null,
    );
