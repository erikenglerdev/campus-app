// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_credential_store.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_failure.dart';
import '../domain/mail_gateway.dart';
import 'mail_providers.dart';

/// Public account state. Deliberately carries the email address and the
/// cosmetic display name — never the password — so nothing downstream can leak
/// the secret.
class MailAccountState {
  const MailAccountState({this.emailAddress, this.displayName});

  final String? emailAddress;
  final String? displayName;

  bool get isSignedIn => emailAddress != null;

  @override
  String toString() => 'MailAccountState(signedIn: $isSignedIn)';
}

/// Owns sign-in, sign-out and the stored account.
///
/// Credentials live only in secure storage; this controller reads them there
/// when it needs to talk to the gateway and never keeps the password in a field
/// or in its public state.
class MailAccountController extends AsyncNotifier<MailAccountState> {
  MailCredentialStore get _store => ref.read(mailCredentialStoreProvider);
  MailGateway get _gateway => ref.read(mailGatewayProvider);

  @override
  Future<MailAccountState> build() async {
    final MailCredentials? stored = await _store.read();
    return MailAccountState(
      emailAddress: stored?.emailAddress,
      displayName: stored?.displayName,
    );
  }

  /// Reads the stored credentials for a gateway call, or throws if signed out.
  Future<MailCredentials> requireCredentials() async {
    final MailCredentials? stored = await _store.read();
    if (stored == null) {
      throw const MailFailure(MailFailureKind.invalidCredentials);
    }
    return stored;
  }

  /// Verifies IMAP + SMTP, then — only on success — stores the credentials.
  ///
  /// [displayName] is optional and purely cosmetic (the friendly part of the
  /// `From` header); it plays no role in authentication.
  Future<void> signIn({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final String address = normalizeEmailAddress(email);
    if (!isValidEmailAddress(address)) {
      throw const MailFailure(MailFailureKind.invalidEmail);
    }
    final String? name = displayName?.trim();
    final MailCredentials credentials = MailCredentials(
      emailAddress: address,
      password: password,
      displayName: (name != null && name.isNotEmpty) ? name : null,
    );

    // Verify before persisting: a wrong password must never be written.
    await _gateway.verifyConnection(credentials);
    await _store.write(credentials);

    // The inbox watches this controller, so publishing the new account state is
    // enough to make it rebuild for the new mailbox — no manual invalidation,
    // which would be a circular dependency (the inbox depends on us).
    state = AsyncData(
      MailAccountState(
        emailAddress: address,
        displayName: credentials.displayName,
      ),
    );
  }

  /// Closes any connection state and removes both fields from secure storage.
  /// Also wipes the offline mail cache so nothing survives for the next account.
  Future<void> signOut() async {
    await _store.clear();
    try {
      await ref.read(mailCacheStoreProvider).clear();
    } catch (_) {}
    state = const AsyncData(MailAccountState());
  }
}

final AsyncNotifierProvider<MailAccountController, MailAccountState>
mailAccountControllerProvider =
    AsyncNotifierProvider<MailAccountController, MailAccountState>(
      MailAccountController.new,
    );
