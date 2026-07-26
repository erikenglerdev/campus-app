// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../application/grade_account_controller.dart';
import 'grade_setup_screen.dart';
import 'grades_overview_screen.dart';

/// Entry point of the grades area at `/more/grades`.
///
/// A pure gate: the setup screen while no account is stored, the overview once
/// one exists. Signing in and deleting the account both flow through
/// [gradeAccountControllerProvider], so the switch is automatic.
class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GradeAccountState> account = ref.watch(
      gradeAccountControllerProvider,
    );
    return account.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => const GradeSetupScreen(),
      data: (GradeAccountState state) => state.isSignedIn
          ? const GradesOverviewScreen()
          : const GradeSetupScreen(),
    );
  }
}
