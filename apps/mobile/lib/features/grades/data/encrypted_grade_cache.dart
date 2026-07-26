// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:convert';

import '../../../core/cache/encrypted_box.dart';
import '../domain/grade.dart';
import '../domain/grade_cache_store.dart';
import 'grade_cache_codec.dart';

/// [GradeCacheStore] backed by the shared [EncryptedBox] (encrypted at rest with
/// a device-held 256-bit key). Grades are never written to a plain box or to
/// SharedPreferences; [clear] wipes the box AND its key.
///
/// Reads are best effort; only a successfully fetched report is ever written, so
/// the last good cache always survives a failed sync.
class EncryptedGradeCache implements GradeCacheStore {
  EncryptedGradeCache([EncryptedBox? box])
    : _box =
          box ??
          EncryptedBox(
            boxName: 'campus_grades_cache_v1',
            keyStorageKey: 'grades.cache.key.v1',
          );

  final EncryptedBox _box;

  static const String _reportKey = 'report';
  static const String _lastSuccessKey = 'lastSuccess';
  static const String _lastAttemptKey = 'lastAttempt';

  @override
  Future<GradeReport?> readReport() async {
    final String? raw = await _box.read(_reportKey);
    if (raw == null) return null;
    try {
      return GradeCacheCodec.reportFrom(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeReport(GradeReport report) =>
      _box.write(_reportKey, jsonEncode(GradeCacheCodec.report(report)));

  @override
  Future<DateTime?> readLastSuccessfulSync() => _readDate(_lastSuccessKey);

  @override
  Future<void> writeLastSuccessfulSync(DateTime at) =>
      _writeDate(_lastSuccessKey, at);

  @override
  Future<DateTime?> readLastAttemptedSync() => _readDate(_lastAttemptKey);

  @override
  Future<void> writeLastAttemptedSync(DateTime at) =>
      _writeDate(_lastAttemptKey, at);

  Future<DateTime?> _readDate(String key) async {
    final String? raw = await _box.read(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _writeDate(String key, DateTime at) =>
      _box.write(key, at.toUtc().toIso8601String());

  @override
  Future<void> clear() => _box.wipe();
}
