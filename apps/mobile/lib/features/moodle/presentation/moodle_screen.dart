// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../application/moodle_account_controller.dart';
import '../domain/moodle_account.dart';
import 'moodle_overview_screen.dart';
import 'moodle_setup_screen.dart';

/// Entry point of the Moodle area at `/more/moodle`.
///
/// A pure gate: the setup screen while no account is connected, the overview
/// once a token exists. Connecting and disconnecting both flow through
/// [moodleAccountControllerProvider], so the switch is automatic.
class MoodleScreen extends ConsumerWidget {
  const MoodleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MoodleAccount?> account = ref.watch(
      moodleAccountControllerProvider,
    );
    return account.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => const MoodleSetupScreen(),
      data: (MoodleAccount? state) => state == null
          ? const MoodleSetupScreen()
          : const MoodleOverviewScreen(),
    );
  }
}
