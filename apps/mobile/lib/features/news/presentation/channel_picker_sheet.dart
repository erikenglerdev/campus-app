// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/icon_keys.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/channel_subscriptions.dart';
import '../application/news_providers.dart';
import '../data/news_models.dart';

/// Opens the channel picker as a modal bottom sheet.
Future<void> showChannelPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.lg),
        child: ChannelPickerList(showTitle: true),
      ),
    ),
  );
}

/// Lets the user subscribe to and unsubscribe from channels.
///
/// The list is built entirely from the API response — there is no hard-coded
/// channel anywhere in the app.
class ChannelPickerList extends ConsumerWidget {
  const ChannelPickerList({this.showTitle = false, super.key});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<NewsChannel>>> channels = ref.watch(
      newsChannelsProvider,
    );
    final ChannelSubscriptionState subscriptions = ref.watch(
      channelSubscriptionProvider,
    );

    return switch (channels) {
      AsyncLoading<Loaded<List<NewsChannel>>>() when !channels.hasValue =>
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: LoadingView(),
        ),
      AsyncError<Loaded<List<NewsChannel>>>(:final Object error) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(newsChannelsProvider),
        ),
      ),
      _ => _buildList(
        context,
        ref,
        l10n,
        channels.requireValue.value,
        subscriptions,
      ),
    };
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<NewsChannel> channels,
    ChannelSubscriptionState subscriptions,
  ) {
    if (channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyView(
          icon: Icons.rss_feed_outlined,
          title: l10n.newsNoChannelsAvailableTitle,
          message: l10n.newsNoChannelsAvailableMessage,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.newsChannelPickerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            l10n.newsChannelCountLabel(subscriptions.selectedSlugs.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: channels.length,
            itemBuilder: (BuildContext context, int index) {
              final NewsChannel channel = channels[index];
              final bool subscribed = subscriptions.isSubscribed(channel.slug);
              return SwitchListTile.adaptive(
                value: subscribed,
                secondary: Icon(IconKeys.resolve(channel.iconKey)),
                title: Text(channel.name),
                // The subscription state is spelled out in words and carries an
                // icon, so it is never communicated by the switch colour alone.
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (channel.description != null) Text(channel.description!),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          subscribed
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: AppSpacing.lg,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            subscribed
                                ? l10n.newsChannelSelected(channel.name)
                                : l10n.newsChannelDeselected(channel.name),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onChanged: (bool value) => ref
                    .read(channelSubscriptionProvider.notifier)
                    .setSubscribed(channel.slug, subscribed: value),
              );
            },
          ),
        ),
      ],
    );
  }
}
