// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/documents/app_document.dart';
import '../../../core/documents/document_share_service.dart';
import '../../../core/documents/document_viewer_screen.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/mail_message.dart';

/// True when [email] belongs to the hs-anhalt.de domain (or a subdomain).
///
/// Mail-specific: images from such senders are shown automatically; images from
/// anyone else are held back behind a "load image" tap. This trust rule stays in
/// the mail feature and never leaks into the generic document viewer.
bool isTrustedImageSender(String email) {
  final int at = email.lastIndexOf('@');
  if (at < 0) return false;
  final String domain = email.substring(at + 1).trim().toLowerCase();
  return domain == 'hs-anhalt.de' || domain.endsWith('.hs-anhalt.de');
}

const DocumentShareService _shareService = DocumentShareService();

AppDocument _asDocument(MailAttachment a) => AppDocument(
  filename: a.filename,
  mediaType: a.mediaType,
  bytes: a.bytes!,
  sizeBytes: a.sizeBytes,
);

/// One attachment in the message detail.
///
/// Image attachments from trusted senders preview inline; images from other
/// senders stay hidden behind a "load image" button. Tapping any downloaded
/// attachment opens it in the shared [DocumentViewerScreen].
class MailAttachmentView extends StatefulWidget {
  const MailAttachmentView({
    required this.attachment,
    required this.autoShowImages,
    super.key,
  });

  final MailAttachment attachment;
  final bool autoShowImages;

  @override
  State<MailAttachmentView> createState() => _MailAttachmentViewState();
}

class _MailAttachmentViewState extends State<MailAttachmentView> {
  late bool _revealed = widget.autoShowImages;

  MailAttachment get _a => widget.attachment;

  void _open() {
    final AppLocalizations l10n = context.l10n;
    if (_a.bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mailAttachmentNotDownloaded)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            DocumentViewerScreen(document: _asDocument(_a)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int? size = _a.sizeBytes;
    final String subtitle = <String>[
      _a.mediaType,
      if (size != null) humanFileSize(size),
    ].join(' · ');

    final Widget tile = ListTile(
      leading: Icon(
        _a.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
      ),
      title: Text(_a.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, style: text.bodySmall),
      onTap: _open,
      trailing: _a.bytes == null
          ? null
          : IconButton(
              onPressed: () => _shareService.share(_asDocument(_a)),
              tooltip: l10n.mailAttachmentShare,
              icon: const Icon(Icons.ios_share),
            ),
    );

    // A held-back image: metadata plus a "load image" button.
    if (_a.isImage && !_revealed) {
      return Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(
                _a.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(subtitle, style: text.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _revealed = true),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.mailAttachmentLoadImage),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Uint8List? imageBytes = _a.isImage ? _a.bytes : null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (imageBytes != null)
            InkWell(
              onTap: _open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          tile,
        ],
      ),
    );
  }
}
