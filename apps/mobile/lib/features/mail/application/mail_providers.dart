// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enough_mail_gateway.dart';
import '../data/mail_cache.dart';
import '../data/secure_mail_credential_store.dart';
import '../domain/hsa_mail_profile.dart';
import '../domain/mail_cache_store.dart';
import '../domain/mail_credential_store.dart';
import '../domain/mail_gateway.dart';

/// The pinned HSA connection profile.
final Provider<HsaMailProfile> hsaMailProfileProvider =
    Provider<HsaMailProfile>((Ref ref) => const HsaMailProfile());

/// Secure credential storage. Overridden with an in-memory fake in tests.
final Provider<MailCredentialStore> mailCredentialStoreProvider =
    Provider<MailCredentialStore>((Ref ref) => SecureMailCredentialStore());

/// The mail gateway (enough_mail behind an interface). Overridden in tests.
final Provider<MailGateway> mailGatewayProvider = Provider<MailGateway>(
  (Ref ref) => EnoughMailGateway(ref.watch(hsaMailProfileProvider)),
);

/// Offline mail cache. Overridden in `main()` with the Hive-backed store and in
/// tests with an in-memory one; the default keeps widget tests off the disk.
final Provider<MailCacheStore> mailCacheStoreProvider =
    Provider<MailCacheStore>((Ref ref) => MemoryMailCache());
