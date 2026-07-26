// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/encrypted_moodle_cache.dart';
import '../data/moodle_file_downloader.dart';
import '../data/moodle_http_client.dart';
import '../data/moodle_repository_impl.dart';
import '../data/secure_moodle_token_store.dart';
import '../domain/moodle_account.dart';
import '../domain/moodle_api_client.dart';
import '../domain/moodle_cache.dart';
import '../domain/moodle_downloader.dart';
import '../domain/moodle_profile.dart';
import '../domain/moodle_repository.dart';

/// The pinned Moodle endpoints (host allowlist).
final Provider<MoodleProfile> moodleProfileProvider = Provider<MoodleProfile>(
  (Ref ref) => const MoodleProfile(),
);

/// The read-only Moodle Web Services client. Overridden in tests.
final Provider<MoodleApiClient> moodleApiClientProvider =
    Provider<MoodleApiClient>(
      (Ref ref) => MoodleHttpClient(profile: ref.watch(moodleProfileProvider)),
    );

/// Secure token storage (device keychain/keystore). Overridden in tests.
final Provider<MoodleTokenStore> moodleTokenStoreProvider =
    Provider<MoodleTokenStore>((Ref ref) => SecureMoodleTokenStore());

/// The encrypted on-device cache. Overridden in tests.
final Provider<MoodleCacheStore> moodleCacheStoreProvider =
    Provider<MoodleCacheStore>((Ref ref) => EncryptedMoodleCache());

/// The guarded file downloader. Overridden in tests.
final Provider<MoodleFileDownloader> moodleFileDownloaderProvider =
    Provider<MoodleFileDownloader>(
      (Ref ref) =>
          MoodleFileDownloaderImpl(profile: ref.watch(moodleProfileProvider)),
    );

/// Injectable clock so the 24-hour policy is testable.
final Provider<Clock> moodleClockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

/// The single Moodle facade. Owns the token and the cache.
final Provider<MoodleRepository> moodleRepositoryProvider =
    Provider<MoodleRepository>(
      (Ref ref) => MoodleRepositoryImpl(
        apiClient: ref.watch(moodleApiClientProvider),
        tokenStore: ref.watch(moodleTokenStoreProvider),
        cacheStore: ref.watch(moodleCacheStoreProvider),
        fileDownloader: ref.watch(moodleFileDownloaderProvider),
        clock: ref.watch(moodleClockProvider),
      ),
    );
