// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clock.dart';
import '../domain/grade.dart';
import '../domain/grade_cache_store.dart';
import '../domain/grade_credential_store.dart';
import '../domain/grade_credentials.dart';
import '../domain/grade_failure.dart';
import '../domain/grades_gateway.dart';
import 'grades_providers.dart';

/// Public account state — deliberately carries ONLY the username, never the
/// password, so nothing downstream can leak the secret.
class GradeAccountState {
  const GradeAccountState({this.username});

  final String? username;

  bool get isSignedIn => username != null;

  @override
  String toString() => 'GradeAccountState(signedIn: $isSignedIn)';
}

/// Owns setup and removal of the QIS account.
///
/// Credentials live only in secure storage; the password is read from there
/// just before a portal call and is never held in a field or in the state.
class GradeAccountController extends AsyncNotifier<GradeAccountState> {
  GradeCredentialStore get _store => ref.read(gradeCredentialStoreProvider);
  GradesGateway get _gateway => ref.read(gradesGatewayProvider);
  GradeCacheStore get _cache => ref.read(gradeCacheStoreProvider);
  Clock get _clock => ref.read(gradeClockProvider);

  @override
  Future<GradeAccountState> build() async {
    final GradeCredentials? stored = await _store.read();
    return GradeAccountState(username: stored?.username);
  }

  /// Reads the stored credentials for a portal call, or throws if signed out.
  Future<GradeCredentials> requireCredentials() async {
    final GradeCredentials? stored = await _store.read();
    if (stored == null) {
      throw const GradeFailure(GradeFailureKind.invalidCredentials);
    }
    return stored;
  }

  /// Verifies the login by actually reaching the Notenspiegel, then — only on
  /// success — stores the credentials and seeds the encrypted cache. Returns the
  /// fetched report. Throws [GradeFailure] on any problem; nothing is stored.
  Future<GradeReport> signIn({
    required String username,
    required String password,
  }) async {
    final String user = normalizeUsername(username);
    if (!isValidUsername(user) || !isValidPassword(password)) {
      throw const GradeFailure(GradeFailureKind.invalidCredentials);
    }
    final GradeCredentials credentials = GradeCredentials(
      username: user,
      password: password,
    );

    // Verify before persisting: wrong credentials must never be written.
    final GradeReport report = await _gateway.fetchGrades(credentials);

    // Success → persist the account, seed the cache and stamp both times.
    await _store.write(credentials);
    final DateTime now = _clock.now();
    await _cache.writeReport(report);
    await _cache.writeLastSuccessfulSync(now);
    await _cache.writeLastAttemptedSync(now);

    // The grades controller watches this state, so publishing it rebuilds the
    // overview onto the fresh cache — no manual invalidation needed.
    state = AsyncData(GradeAccountState(username: user));
    return report;
  }

  /// "Delete credentials and local grades": wipes secure storage, the encrypted
  /// cache, its key and all sync timestamps, then resets the state.
  Future<void> deleteEverything() async {
    await _store.clear();
    try {
      await _cache.clear();
    } catch (_) {}
    state = const AsyncData(GradeAccountState());
  }
}

final AsyncNotifierProvider<GradeAccountController, GradeAccountState>
gradeAccountControllerProvider =
    AsyncNotifierProvider<GradeAccountController, GradeAccountState>(
      GradeAccountController.new,
    );
