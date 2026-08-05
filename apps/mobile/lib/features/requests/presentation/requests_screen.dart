// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../domain/request_models.dart';

/// Applications and feedback.
///
/// The screen states up front that this build cannot submit anything. That is
/// not a disclaimer bolted on at the end — a form that looks like it files an
/// application, and does not, is worse than no form at all.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final String locale = Localizations.localeOf(context).languageCode;
    final AsyncValue<List<RequestDraft>> drafts = ref.watch(requestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsTitle)),
      body: ListView(
        padding: EdgeInsets.all(metrics.screenPadding),
        children: <Widget>[
          // Said once, prominently, before anything can be typed.
          // Only while there is genuinely nowhere to submit. A build that can
          // submit must not keep claiming it cannot.
          if (!ref.watch(requestsEndpointConfiguredProvider)) ...<Widget>[
            StatusBanner(
              tone: StatusTone.warning,
              icon: Icons.construction_outlined,
              title: l10n.requestsDevNoticeTitle,
              message: l10n.requestsDevNoticeBody,
            ),
            SizedBox(height: metrics.sectionGap),
          ],

          _KindTile(
            kind: RequestKind.financeApplication,
            icon: Icons.euro_symbol,
            title: l10n.requestsFinanceTitle,
            subtitle: l10n.requestsFinanceSubtitle,
          ),
          SizedBox(height: metrics.cardGap),
          _KindTile(
            kind: RequestKind.feedback,
            icon: Icons.forum_outlined,
            title: l10n.requestsFeedbackTitle,
            subtitle: l10n.requestsFeedbackSubtitle,
          ),

          SizedBox(height: metrics.sectionGap),
          Semantics(
            header: true,
            child: Text(
              l10n.requestsDrafts,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (drafts) {
            AsyncError<List<RequestDraft>>() => Text(
              l10n.requestsNoDrafts,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            AsyncData<List<RequestDraft>>(:final List<RequestDraft> value)
                when value.isEmpty =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: EmptyView(
                  icon: Icons.drafts_outlined,
                  title: l10n.requestsNoDrafts,
                  message: l10n.requestsAttachmentsHint,
                ),
              ),
            AsyncData<List<RequestDraft>>(:final List<RequestDraft> value) =>
              Column(
                children: <Widget>[
                  for (final RequestDraft draft in value)
                    _DraftTile(draft: draft, locale: locale),
                ],
              ),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final RequestKind kind;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(
          context,
        ).push('${AppRoutes.requests}/draft/new?kind=${kind.storageValue}'),
      ),
    );
  }
}

class _DraftTile extends ConsumerWidget {
  const _DraftTile({required this.draft, required this.locale});

  final RequestDraft draft;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String title = draft.title.trim().isEmpty
        ? l10n.requestsNewDraft
        : draft.title.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          draft.kind == RequestKind.financeApplication
              ? Icons.euro_symbol
              : Icons.forum_outlined,
        ),
        title: Text(title),
        subtitle: Text(AppDateFormats.dateTime(draft.updatedAt, locale)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.requestsDeleteDraft,
          onPressed: () async {
            final bool confirmed =
                await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) => AlertDialog(
                    title: Text(l10n.requestsDeleteConfirm),
                    content: Text(title),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          MaterialLocalizations.of(
                            dialogContext,
                          ).cancelButtonLabel,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(l10n.requestsDeleteDraft),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (!confirmed) return;
            await ref.read(requestsProvider.notifier).delete(draft.id);
          },
        ),
        onTap: () => GoRouter.of(
          context,
        ).push('${AppRoutes.requests}/draft/${draft.id}'),
      ),
    );
  }
}
