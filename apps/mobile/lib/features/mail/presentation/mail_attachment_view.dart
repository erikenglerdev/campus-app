// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/mail_message.dart';

/// True when [email] belongs to the hs-anhalt.de domain (or a subdomain).
///
/// Images from such senders are shown automatically; images from anyone else
/// are held back behind a "load image" tap.
bool isTrustedImageSender(String email) {
  final int at = email.lastIndexOf('@');
  if (at < 0) return false;
  final String domain = email.substring(at + 1).trim().toLowerCase();
  return domain == 'hs-anhalt.de' || domain.endsWith('.hs-anhalt.de');
}

bool _isPdf(MailAttachment a) =>
    a.mediaType.toLowerCase() == 'application/pdf' ||
    a.filename.toLowerCase().endsWith('.pdf');

bool _isText(MailAttachment a) => a.mediaType.toLowerCase().startsWith('text/');

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Future<void> _shareAttachment(MailAttachment a) async {
  final Uint8List? bytes = a.bytes;
  if (bytes == null) return;
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile.fromData(bytes, mimeType: a.mediaType)],
      fileNameOverrides: <String>[a.filename],
    ),
  );
}

/// One attachment in the message detail.
///
/// Image attachments from trusted senders preview inline; images from other
/// senders stay hidden behind a "load image" button. Tapping any downloaded
/// attachment opens it in an in-app viewer.
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
        builder: (BuildContext _) => AttachmentViewerScreen(attachment: _a),
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
      if (size != null) _sizeLabel(size),
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
              onPressed: () => _shareAttachment(_a),
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

/// Full-screen in-app viewer for a downloaded attachment: images (zoomable),
/// PDFs (native renderer, no WebView) and plain text. Anything else offers a
/// share/save action instead.
class AttachmentViewerScreen extends StatefulWidget {
  const AttachmentViewerScreen({required this.attachment, super.key});

  final MailAttachment attachment;

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  PdfControllerPinch? _pdf;

  @override
  void initState() {
    super.initState();
    final MailAttachment a = widget.attachment;
    final Uint8List? bytes = a.bytes;
    if (bytes != null && _isPdf(a)) {
      _pdf = PdfControllerPinch(document: PdfDocument.openData(bytes));
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MailAttachment a = widget.attachment;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (a.bytes != null)
            IconButton(
              onPressed: () => _shareAttachment(a),
              tooltip: l10n.mailAttachmentShare,
              icon: const Icon(Icons.ios_share),
            ),
        ],
      ),
      body: _body(context, l10n, a),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, MailAttachment a) {
    final Uint8List? bytes = a.bytes;
    if (bytes == null) {
      return _Centered(text: l10n.mailAttachmentNotDownloaded);
    }
    if (a.isImage) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.memory(
            bytes,
            errorBuilder: (_, _, _) =>
                _Centered(text: l10n.mailAttachmentPreviewUnavailable),
          ),
        ),
      );
    }
    if (_pdf != null) {
      return PdfViewPinch(controller: _pdf!);
    }
    if (_isText(a)) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SelectableText(
          utf8.decode(bytes, allowMalformed: true),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return _Centered(text: l10n.mailAttachmentPreviewUnavailable);
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
