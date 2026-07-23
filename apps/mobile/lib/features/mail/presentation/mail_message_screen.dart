// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import '../application/mail_folders.dart';
import '../application/mail_inbox_controller.dart';
import '../domain/mail_message.dart';
import 'compose_draft.dart';
import 'mail_error_messages.dart';

/// Reads one message. The body is already reduced to safe plain text by the
/// gateway (text/plain preferred, HTML sanitised): there is no WebView, no
/// JavaScript and no remote image loading here.
class MailMessageScreen extends ConsumerWidget {
  const MailMessageScreen({required this.id, super.key});

  final String id;

  /// Opens the compose screen pre-filled as a reply (or reply-all) to [detail].
  void _reply(
    BuildContext context,
    WidgetRef ref,
    MailMessageDetail detail, {
    required bool all,
  }) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final String sender = detail.from.display.trim().isEmpty
        ? detail.from.email
        : detail.from.display;
    final String date = detail.date != null
        ? AppDateFormats.dateTime(detail.date!, locale)
        : '';
    final String attribution = l10n.mailReplyAttribution(date, sender);
    final String self =
        ref.read(mailAccountControllerProvider).value?.emailAddress ?? '';

    final ComposeDraft draft = all
        ? ComposeDraft.replyAll(
            detail,
            selfEmail: self,
            attribution: attribution,
          )
        : ComposeDraft.reply(detail, attribution: attribution);
    context.push(AppRoutes.mailCompose, extra: draft);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final MailMessageRef messageRef = (
      mailboxPath: ref.watch(selectedMailboxProvider).path,
      id: id,
    );
    final AsyncValue<MailMessageDetail> message = ref.watch(
      mailMessageProvider(messageRef),
    );
    final MailMessageDetail? detail = message.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mailTitle),
        actions: detail == null
            ? null
            : <Widget>[
                IconButton(
                  onPressed: () => _reply(context, ref, detail, all: false),
                  tooltip: l10n.mailReply,
                  icon: const Icon(Icons.reply),
                ),
                IconButton(
                  onPressed: () => _reply(context, ref, detail, all: true),
                  tooltip: l10n.mailReplyAll,
                  icon: const Icon(Icons.reply_all),
                ),
              ],
      ),
      body: message.when(
        loading: () => const LoadingView(),
        error: (Object error, _) => EmptyView(
          icon: Icons.error_outline,
          title: l10n.errorGenericTitle,
          message: mailFailureMessage(l10n, error),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(mailMessageProvider(messageRef)),
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
        SelectableText(detail.body, style: text.bodyLarge),
        if (detail.hasAttachments) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(l10n.mailAttachmentsTitle, style: text.titleMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final MailAttachment attachment in detail.attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AttachmentView(attachment: attachment),
            ),
        ],
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

/// Renders one attachment: image attachments show an inline preview from
/// memory (nothing is written to disk, nothing is fetched from the network);
/// everything else shows a metadata tile.
class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final MailAttachment attachment;

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _share() async {
    final Uint8List? bytes = attachment.bytes;
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile.fromData(bytes, mimeType: attachment.mediaType)],
        fileNameOverrides: <String>[attachment.filename],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int? size = attachment.sizeBytes;
    final Uint8List? imageBytes = attachment.isImage ? attachment.bytes : null;
    final String subtitle = <String>[
      attachment.mediaType,
      if (size != null) _sizeLabel(size),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (imageBytes != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ListTile(
            leading: Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
            ),
            title: Text(
              attachment.filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(subtitle, style: text.bodySmall),
            // A share/save action only appears once the content is downloaded.
            trailing: attachment.isDownloaded
                ? IconButton(
                    onPressed: _share,
                    tooltip: l10n.mailAttachmentShare,
                    icon: const Icon(Icons.ios_share),
                  )
                : null,
          ),
        ],
      ),
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
