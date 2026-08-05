// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../domain/request_models.dart';

/// What the receiving system said after an application was filed.
///
/// The status link is the point of this screen and also its hazard: it is the
/// only way back to the application and it authenticates nobody who holds it.
/// So it is shown, it can be copied and opened, and it is stated plainly that
/// it must not be shared. It is never logged.
class SubmissionResultScreen extends StatelessWidget {
  const SubmissionResultScreen({required this.request, this.onOpen, super.key});

  final SubmittedRequest request;

  /// Injected in tests; production hands the URL to the platform.
  final Future<void> Function(String url)? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsResultTitle)),
      body: ListView(
        padding: EdgeInsets.all(metrics.screenPadding),
        children: <Widget>[
          StatusBanner(
            tone: StatusTone.positive,
            icon: Icons.check_circle_outline,
            title: l10n.requestsResultTitle,
            message: request.wasReplay ? l10n.requestsResultReplayed : null,
          ),
          SizedBox(height: metrics.sectionGap),

          Text(request.title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.number == null
                ? l10n.requestsResultNoNumber
                : l10n.requestsResultNumber(request.number!),
            style: text.bodyMedium,
          ),

          SizedBox(height: metrics.sectionGap),
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.vpn_key_outlined,
            title: l10n.requestsResultSecretHint,
          ),
          const SizedBox(height: AppSpacing.md),

          if (request.hasSafeTrackingUrl)
            _LinkRow(
              label: l10n.requestsResultOpenStatus,
              url: request.trackingUrl!,
              icon: Icons.open_in_new,
              onOpen: onOpen,
            ),
          if (request.hasSafeReceiptUrl) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _LinkRow(
              label: l10n.requestsResultOpenReceipt,
              url: request.receiptPdfUrl!,
              icon: Icons.picture_as_pdf_outlined,
              onOpen: onOpen,
            ),
          ],

          SizedBox(height: metrics.sectionGap),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.requestsResultDone),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.url,
    required this.icon,
    this.onOpen,
  });

  final String label;
  final String url;
  final IconData icon;
  final Future<void> Function(String url)? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Shown in full: the user may want to write it down, and a truncated
        // secret is useless.
        SelectableText(url, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        OverflowBar(
          spacing: AppSpacing.sm,
          overflowSpacing: AppSpacing.xs,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => onOpen?.call(url),
              icon: Icon(icon),
              label: Text(label),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.commonCopied)));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l10n.commonCopy),
            ),
          ],
        ),
      ],
    );
  }
}
