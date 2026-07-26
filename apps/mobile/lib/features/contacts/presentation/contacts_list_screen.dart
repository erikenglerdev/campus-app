// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/icon_keys.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/contacts_providers.dart';
import '../data/contact_models.dart';

/// Lists the contact areas. Areas without any person are ordinary entries.
class ContactsListScreen extends ConsumerWidget {
  const ContactsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<ContactArea>>> areas = ref.watch(
      contactAreasProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contactAreasProvider);
          await ref.read(contactAreasProvider.future);
        },
        child: switch (areas) {
          AsyncLoading<Loaded<List<ContactArea>>>() when !areas.hasValue =>
            const LoadingView(),
          AsyncError<Loaded<List<ContactArea>>>(:final Object error) =>
            ErrorView(
              failure: error,
              onRetry: () => ref.invalidate(contactAreasProvider),
            ),
          _ => _AreaList(loaded: areas.requireValue),
        },
      ),
    );
  }
}

class _AreaList extends StatelessWidget {
  const _AreaList({required this.loaded});

  final Loaded<List<ContactArea>> loaded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ContactArea> areas = loaded.value;

    if (areas.isEmpty) {
      return EmptyView(
        icon: Icons.contact_support_outlined,
        title: l10n.contactsEmptyTitle,
        message: l10n.contactsEmptyMessage,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: areas.length + (loaded.fromCache ? 1 : 0),
      separatorBuilder: (BuildContext _, int _) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        if (loaded.fromCache && index == 0) {
          return OfflineNotice(cachedAt: loaded.cachedAt);
        }
        final ContactArea area = areas[loaded.fromCache ? index - 1 : index];
        return _AreaCard(area: area);
      },
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area});

  final ContactArea area;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: l10n.contactAreaSemanticLabel(area.name),
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(
            AppRoutes.contactAreaName,
            pathParameters: <String, String>{'slug': area.slug},
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(IconKeys.resolve(area.iconKey), size: AppSizes.icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(area.name, style: text.titleMedium),
                        if (area.shortDescription != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(area.shortDescription!, style: text.bodyMedium),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.contactPersonCount(area.personCount),
                          style: text.bodySmall,
                        ),
                        if (area.isDemoContent) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.science_outlined,
                                size: AppSpacing.lg,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                l10n.contactsDemoBadge,
                                style: text.labelMedium,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
