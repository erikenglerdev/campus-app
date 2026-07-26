// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// A string key/value store backed by an ENCRYPTED `hive_ce` box.
///
/// The single home for the app's at-rest encryption of personal data (grades,
/// Moodle): the box is opened with a random 256-bit AES key from a
/// cryptographically secure source ([HiveInterface.generateSecureKey]); only
/// that key lives in the keychain/keystore. [wipe] removes the key together with
/// the box contents, so the leftover ciphertext becomes unreadable.
///
/// All operations are best effort — a corrupt or unavailable box degrades to
/// "empty", never a crash. Never store a plaintext personal value through any
/// other store; route it through here.
class EncryptedBox {
  EncryptedBox({
    required this.boxName,
    required this.keyStorageKey,
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  /// The Hive box name (its file on disk).
  final String boxName;

  /// The secure-storage key under which the AES key is kept.
  final String keyStorageKey;

  final FlutterSecureStorage _storage;

  Box<String>? _box;

  Future<Box<String>?> _open() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      await Hive.initFlutter();
      final List<int> key = await _encryptionKey();
      _box = await Hive.openBox<String>(
        boxName,
        encryptionCipher: HiveAesCipher(key),
      );
      return _box;
    } catch (_) {
      return null; // degrade to "empty", never crash
    }
  }

  Future<List<int>> _encryptionKey() async {
    final String? existing = await _storage.read(key: keyStorageKey);
    if (existing != null) {
      try {
        return base64Decode(existing);
      } catch (_) {
        // Corrupt stored key → start over with a fresh one.
      }
    }
    final List<int> key = Hive.generateSecureKey(); // 256-bit, CSPRNG
    await _storage.write(key: keyStorageKey, value: base64Encode(key));
    return key;
  }

  Future<String?> read(String key) async => (await _open())?.get(key);

  Future<void> write(String key, String value) async {
    try {
      await (await _open())?.put(key, value);
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    try {
      await (await _open())?.delete(key);
    } catch (_) {}
  }

  Future<Iterable<String>> keys() async =>
      (await _open())?.keys.whereType<String>() ?? const <String>[];

  /// Clears the box AND deletes the encryption key.
  Future<void> wipe() async {
    try {
      await (await _open())?.clear();
    } catch (_) {}
    try {
      await _storage.delete(key: keyStorageKey);
    } catch (_) {}
  }
}
