// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';

/// Which legal placeholder page to show.
enum LegalPage { imprint, privacy }

/// Bilingual placeholder for the legally required pages.
///
/// These pages are **release gates**: no address, name, e-mail address or legal
/// text may be invented here. The page states plainly that the content is not
/// final and that the operator has not been confirmed. The independence notice
/// is repeated so the page is self-contained.
class LegalPlaceholderScreen extends StatelessWidget {
  const LegalPlaceholderScreen({required this.page, super.key});

  final LegalPage page;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String title = switch (page) {
      LegalPage.imprint => l10n.imprintTitle,
      LegalPage.privacy => l10n.privacyTitle,
    };
    final String body = switch (page) {
      LegalPage.imprint => l10n.imprintPlaceholderBody,
      LegalPage.privacy => l10n.privacyPlaceholderBody,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.construction_outlined,
            title: l10n.legalPlaceholderTitle,
            message: l10n.legalNotPublishedHint,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(title, style: text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.legalOperatorNotConfirmed, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              l10n.aboutIndependenceTitle,
              style: text.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.aboutIndependenceNotice, style: text.bodyMedium),
        ],
      ),
    );
  }
}
