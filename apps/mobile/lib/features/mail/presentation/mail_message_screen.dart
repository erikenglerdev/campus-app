// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_inbox_controller.dart';
import '../domain/mail_message.dart';
import 'mail_error_messages.dart';

/// Reads one message. The body is already reduced to safe plain text by the
/// gateway (text/plain preferred, HTML sanitised): there is no WebView, no
/// JavaScript and no remote image loading here.
class MailMessageScreen extends ConsumerWidget {
  const MailMessageScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final AsyncValue<MailMessageDetail> message = ref.watch(
      mailMessageProvider(id),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailTitle)),
      body: message.when(
        loading: () => const LoadingView(),
        error: (Object error, _) => EmptyView(
          icon: Icons.error_outline,
          title: l10n.errorGenericTitle,
          message: mailFailureMessage(l10n, error),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(mailMessageProvider(id)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.mailRetry),
          ),
        ),
        data: (MailMessageDetail detail) =>
            _MessageBody(detail: detail, locale: locale),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.detail, required this.locale});

  final MailMessageDetail detail;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String subject = detail.subject.trim().isEmpty
        ? l10n.mailNoSubject
        : detail.subject;
    final String sender = detail.from.display.trim().isEmpty
        ? l10n.mailUnknownSender
        : detail.from.display;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(subject, style: text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Text(
          sender,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (detail.from.name != null &&
            detail.from.name!.trim().isNotEmpty &&
            detail.from.email.trim().isNotEmpty)
          Text(detail.from.email, style: text.bodySmall),
        if (detail.date != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppDateFormats.dateTime(detail.date!, locale),
            style: text.bodySmall,
          ),
        ],
        const Divider(height: AppSpacing.xl),
        if (detail.hasUnsupportedAttachments) ...<Widget>[
          _NoticeBanner(
            icon: Icons.attach_file,
            text: l10n.mailMessageAttachmentsUnsupported,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SelectableText(detail.body, style: text.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        _NoticeBanner(
          icon: Icons.image_not_supported_outlined,
          text: l10n.mailMessageRemoteImagesBlocked,
          muted: true,
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final TextTheme theme = Theme.of(context).textTheme;
    final Color? color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: AppSizes.icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: (muted ? theme.bodySmall : theme.bodyMedium)?.copyWith(
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
