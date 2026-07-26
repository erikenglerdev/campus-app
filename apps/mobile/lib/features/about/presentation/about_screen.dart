// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';

/// Version information the About screen shows.
class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

/// Reads the bundled version metadata. Overridden in tests.
final FutureProvider<AppVersionInfo> appVersionProvider =
    FutureProvider<AppVersionInfo>((Ref ref) async {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return AppVersionInfo(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    });

/// About screen: identity, licence, copyright and the binding independence
/// notice.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final AsyncValue<AppVersionInfo> version = ref.watch(appVersionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.appTitle, style: text.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (version.hasValue)
            Text(
              l10n.aboutVersion(
                version.requireValue.version,
                version.requireValue.buildNumber,
              ),
              style: text.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.xl),
          _KeyValueRow(
            label: l10n.aboutLicenseLabel,
            value: l10n.aboutLicenseValue,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.aboutCopyright, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          StatusBanner(
            icon: Icons.info_outline,
            title: l10n.aboutIndependenceTitle,
            message: l10n.aboutIndependenceNotice,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.aboutFontNotice, style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationLegalese: l10n.aboutCopyright,
                applicationVersion: version.hasValue
                    ? version.requireValue.version
                    : null,
              ),
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.aboutOpenSourceLicenses),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label, style: text.titleSmall)),
        Expanded(child: Text(value, style: text.bodyMedium)),
      ],
    );
  }
}
