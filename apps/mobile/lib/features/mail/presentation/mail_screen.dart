// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../application/mail_account_controller.dart';
import 'mail_inbox_screen.dart';
import 'mail_setup_screen.dart';

/// Entry point of the student email client at `/more/mail`.
///
/// A pure gate: it shows the sign-in screen while there is no stored account
/// and the inbox once one exists. Signing in and removing the account both flow
/// through [mailAccountControllerProvider], so the switch is automatic.
class MailScreen extends ConsumerWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MailAccountState> account = ref.watch(
      mailAccountControllerProvider,
    );
    return account.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (_, _) => const MailSetupScreen(),
      data: (MailAccountState state) =>
          state.isSignedIn ? const MailInboxScreen() : const MailSetupScreen(),
    );
  }
}
