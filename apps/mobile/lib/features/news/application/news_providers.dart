// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'channel_subscriptions.dart';

/// The full channel list. Also the single place where `defaultSubscribed` is
/// folded into the local subscription store.
final FutureProvider<Loaded<List<NewsChannel>>> newsChannelsProvider =
    FutureProvider<Loaded<List<NewsChannel>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      final Loaded<List<NewsChannel>> loaded = await ref
          .watch(newsRepositoryProvider)
          .fetchChannels(locale: locale);
      await ref
          .read(channelSubscriptionProvider.notifier)
          .reconcile(loaded.value);
      return loaded;
    });
