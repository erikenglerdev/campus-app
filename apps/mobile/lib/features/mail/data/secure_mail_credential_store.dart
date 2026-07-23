// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/mail_credential_store.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_failure.dart';

/// [MailCredentialStore] backed by the device keychain/keystore.
///
/// There is NO SharedPreferences or Hive fallback by design: if the secure
/// backend is unavailable, [write] throws so the caller can refuse to store the
/// account rather than silently downgrading to insecure storage. The password
/// is never logged and never placed anywhere but here.
class SecureMailCredentialStore implements MailCredentialStore {
  SecureMailCredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _emailKey = 'mail.hsa.email';
  static const String _passwordKey = 'mail.hsa.password';

  @override
  Future<MailCredentials?> read() async {
    try {
      final String? email = await _storage.read(key: _emailKey);
      final String? password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return MailCredentials(emailAddress: email, password: password);
    } catch (_) {
      // An unreadable keystore is treated as "no account", never as a reason
      // to fall back to insecure storage.
      return null;
    }
  }

  @override
  Future<void> write(MailCredentials credentials) async {
    try {
      await _storage.write(key: _emailKey, value: credentials.emailAddress);
      await _storage.write(key: _passwordKey, value: credentials.password);
    } catch (_) {
      // Do not leak the platform exception (it could echo written values);
      // surface only the classification. Best-effort clean up a partial write.
      try {
        await clear();
      } catch (_) {}
      throw const MailFailure(MailFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}
