// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_credential_store.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_failure.dart';
import '../domain/mail_gateway.dart';
import 'mail_providers.dart';

/// Public account state. Deliberately carries ONLY the email address — never
/// the password — so nothing downstream can leak it.
class MailAccountState {
  const MailAccountState({this.emailAddress});

  final String? emailAddress;

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
    return MailAccountState(emailAddress: stored?.emailAddress);
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
  Future<void> signIn({required String email, required String password}) async {
    final String address = normalizeEmailAddress(email);
    if (!isValidEmailAddress(address)) {
      throw const MailFailure(MailFailureKind.invalidEmail);
    }
    final MailCredentials credentials = MailCredentials(
      emailAddress: address,
      password: password,
    );

    // Verify before persisting: a wrong password must never be written.
    await _gateway.verifyConnection(credentials);
    await _store.write(credentials);

    // The inbox watches this controller, so publishing the new account state is
    // enough to make it rebuild for the new mailbox — no manual invalidation,
    // which would be a circular dependency (the inbox depends on us).
    state = AsyncData(MailAccountState(emailAddress: address));
  }

  /// Closes any connection state and removes both fields from secure storage.
  Future<void> signOut() async {
    await _store.clear();
    state = const AsyncData(MailAccountState());
  }
}

final AsyncNotifierProvider<MailAccountController, MailAccountState>
mailAccountControllerProvider =
    AsyncNotifierProvider<MailAccountController, MailAccountState>(
      MailAccountController.new,
    );
