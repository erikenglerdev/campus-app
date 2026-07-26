// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/encrypted_grade_cache.dart';
import '../data/qis_grades_gateway.dart';
import '../data/secure_grade_credential_store.dart';
import '../domain/clock.dart';
import '../domain/grade_cache_store.dart';
import '../domain/grade_credential_store.dart';
import '../domain/grades_gateway.dart';
import '../domain/qis_profile.dart';

/// The pinned HIS-QIS endpoints (host allowlist).
final Provider<QisProfile> qisProfileProvider = Provider<QisProfile>(
  (Ref ref) => const QisProfile(),
);

/// QIS credentials in the device keychain/keystore. Overridden in tests.
final Provider<GradeCredentialStore> gradeCredentialStoreProvider =
    Provider<GradeCredentialStore>((Ref ref) => SecureGradeCredentialStore());

/// The portal gateway (Dio/cookies/HTML hidden behind the interface).
final Provider<GradesGateway> gradesGatewayProvider = Provider<GradesGateway>(
  (Ref ref) => QisGradesGateway(ref.watch(qisProfileProvider)),
);

/// The encrypted local grade cache. Overridden in tests.
final Provider<GradeCacheStore> gradeCacheStoreProvider =
    Provider<GradeCacheStore>((Ref ref) => EncryptedGradeCache());

/// Injectable clock so the 24-hour policy is testable.
final Provider<Clock> gradeClockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);
