// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../application/news_feed_controller.dart';
import '../application/news_read_controller.dart';
import '../data/news_models.dart';
import '../domain/read_state.dart';
import 'channel_picker_sheet.dart';

/// Opens the one filter the feed has.
///
/// Channel selection and the unread controls live in the **same** sheet, which
/// is what lets the feed get by with a single button at the top instead of a
/// row of icons competing for a phone's width.
Future<void> showNewsFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const NewsFilterSheet(),
  );
}

/// The contents of the news filter sheet.
class NewsFilterSheet extends ConsumerWidget {
  const NewsFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final bool unreadOnly = ref.watch(newsUnreadOnlyProvider);
    final NewsReadState readState = ref.watch(newsReadProvider);
    final List<String> loadedSlugs =
        ref
            .watch(newsFeedControllerProvider)
            .value
            ?.articles
            .map((NewsArticle article) => article.slug)
            .toList(growable: false) ??
        const <String>[];
    final int unread = readState.unreadCount(loadedSlugs);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(l10n.newsFilterTitle, style: text.titleLarge),
              ),
            ),
            SwitchListTile.adaptive(
              value: unreadOnly,
              // The state is spelled out below the label, so it is never the
              // switch's colour alone that says which way it is set.
              title: Text(l10n.newsUnreadOnly),
              subtitle: Text(
                unreadOnly ? l10n.newsUnreadOnly : l10n.newsShowAll,
              ),
              secondary: Icon(
                unreadOnly
                    ? Icons.mark_email_unread
                    : Icons.mark_email_unread_outlined,
              ),
              onChanged: (bool _) =>
                  ref.read(newsUnreadOnlyProvider.notifier).toggle(),
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: Text(l10n.newsMarkAllRead),
              subtitle: Text(l10n.newsUnreadCount(unread)),
              // Nothing unread means nothing to do — the tile says so rather
              // than pretending to act.
              enabled: unread > 0,
              onTap: unread > 0
                  ? () => ref
                        .read(newsReadProvider.notifier)
                        .markAllRead(loadedSlugs)
                  : null,
            ),
            const Divider(),
            const Flexible(child: ChannelPickerList(showTitle: true)),
          ],
        ),
      ),
    );
  }
}
