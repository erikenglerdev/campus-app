// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/moodle_account.dart';
import 'moodle_providers.dart';

/// The publicly observable Moodle connection state.
///
/// Null means "not connected". This never carries a token or password — the
/// token lives only in secure storage behind the repository.
class MoodleAccountController extends AsyncNotifier<MoodleAccount?> {
  @override
  Future<MoodleAccount?> build() =>
      ref.read(moodleRepositoryProvider).currentAccount();

  bool get isConnected => state.value != null;

  /// Verifies credentials and, only on success, stores the token. The password
  /// is never persisted. Throws a [MoodleFailure] on failure.
  Future<void> connect({
    required String username,
    required String password,
  }) async {
    final MoodleAccount account = await ref
        .read(moodleRepositoryProvider)
        .connect(username: username, password: password);
    state = AsyncData<MoodleAccount?>(account);
  }

  /// Wipes token, user id, encrypted cache, cache key and sync timestamps.
  Future<void> disconnect() async {
    await ref.read(moodleRepositoryProvider).disconnect();
    state = const AsyncData<MoodleAccount?>(null);
  }
}

final AsyncNotifierProvider<MoodleAccountController, MoodleAccount?>
moodleAccountControllerProvider =
    AsyncNotifierProvider<MoodleAccountController, MoodleAccount?>(
      MoodleAccountController.new,
      retry: (_, _) => null,
    );
