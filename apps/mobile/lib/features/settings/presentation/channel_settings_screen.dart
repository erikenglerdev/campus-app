// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../news/presentation/channel_picker_sheet.dart';

/// Full-screen variant of the channel picker, reachable from the settings.
class ChannelSettingsScreen extends StatelessWidget {
  const ChannelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsChannels)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.settingsChannelsSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Expanded(child: ChannelPickerList()),
        ],
      ),
    );
  }
}
