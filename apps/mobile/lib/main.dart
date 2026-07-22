// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/campus_app.dart';
import 'core/cache/cache_providers.dart';
import 'core/cache/content_cache.dart';
import 'core/cache/hive_content_cache.dart';
import 'core/prefs/key_value_store.dart';
import 'core/prefs/settings_controller.dart';

/// Entry point.
///
/// The API base URL comes exclusively from
/// `--dart-define=API_BASE_URL=…` (see `core/network/api_config.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Both stores fail soft: a broken cache or preferences backend degrades the
  // app to "network only", it never prevents the app from starting.
  final KeyValueStore keyValueStore = await _openKeyValueStore();
  final ContentCache contentCache = await HiveContentCache.open();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(keyValueStore),
        contentCacheProvider.overrideWithValue(contentCache),
      ],
      child: const CampusApp(),
    ),
  );
}

Future<KeyValueStore> _openKeyValueStore() async {
  try {
    return await SharedPreferencesStore.open();
  } catch (_) {
    return InMemoryKeyValueStore();
  }
}
