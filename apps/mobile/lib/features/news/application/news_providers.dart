// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/api_meta.dart';
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

/// The `channels` query parameter for the current selection, or `null` when
/// there are no channels at all.
final Provider<String?> newsChannelQueryProvider = Provider<String?>((Ref ref) {
  final List<NewsChannel> channels =
      ref.watch(newsChannelsProvider).value?.value ?? const <NewsChannel>[];
  final ChannelSubscriptionState subscriptions = ref.watch(
    channelSubscriptionProvider,
  );
  return ChannelSubscriptionRules.queryValue(
    available: channels,
    selected: subscriptions.selectedSlugs,
  );
});

/// The news list for the current selection.
///
/// When no channel is selected the request is still made with
/// `?channels=` (present but empty) as the contract demands, which yields an
/// empty list — the app never falls back to "all channels".
final FutureProvider<Loaded<NewsPage>> newsFeedProvider =
    FutureProvider<Loaded<NewsPage>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      final Loaded<List<NewsChannel>> channels = await ref.watch(
        newsChannelsProvider.future,
      );
      final ChannelSubscriptionState subscriptions = ref.watch(
        channelSubscriptionProvider,
      );

      if (channels.value.isEmpty) {
        return Loaded<NewsPage>(
          value: const NewsPage(
            articles: <NewsArticle>[],
            page: 1,
            totalPages: 1,
          ),
          meta: ApiMeta.empty,
        );
      }

      final String? channelsParameter = ChannelSubscriptionRules.queryValue(
        available: channels.value,
        selected: subscriptions.selectedSlugs,
      );

      return ref
          .watch(newsRepositoryProvider)
          .fetchArticles(locale: locale, channelsParameter: channelsParameter);
    });

/// A single article including its rich text content.
final newsArticleProvider = FutureProvider.family<Loaded<NewsArticle>, String>((
  Ref ref,
  String slug,
) async {
  final String locale = ref.watch(localeCodeProvider);
  return ref
      .watch(newsRepositoryProvider)
      .fetchArticle(locale: locale, slug: slug);
});
