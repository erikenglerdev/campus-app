// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import '../application/mail_compose_controller.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_gateway.dart';
import 'mail_error_messages.dart';

/// Compose a text-only message. The sender is always the signed-in account
/// address — there is no From field to edit. A send in flight disables the
/// button, and the controller ignores a second trigger, so a message is never
/// sent twice.
class MailComposeScreen extends ConsumerStatefulWidget {
  const MailComposeScreen({super.key});

  @override
  ConsumerState<MailComposeScreen> createState() => _MailComposeScreenState();
}

class _MailComposeScreenState extends ConsumerState<MailComposeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final AppLocalizations l10n = context.l10n;
    if (ref.read(mailComposeControllerProvider)) return; // already sending
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final SendOutcome? outcome = await ref
          .read(mailComposeControllerProvider.notifier)
          .send(
            to: _toController.text,
            subject: _subjectController.text,
            text: _bodyController.text,
          );
      if (outcome == null) return; // a concurrent send was already running
      final String message = outcome.sentCopy == SentCopyResult.appended
          ? l10n.mailComposeSent
          : l10n.mailComposeSentNoCopy;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(mailFailureMessage(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool sending = ref.watch(mailComposeControllerProvider);
    final String? email = ref
        .watch(mailAccountControllerProvider)
        .value
        ?.emailAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mailComposeTitle),
        actions: <Widget>[
          IconButton(
            onPressed: sending ? null : _send,
            tooltip: l10n.mailComposeSend,
            icon: sending
                ? const SizedBox(
                    height: AppSizes.icon,
                    width: AppSizes.icon,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              if (email != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.mailComposeFrom(email),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              TextFormField(
                controller: _toController,
                enabled: !sending,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.mailComposeTo,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: (String? value) =>
                    isValidEmailAddress(normalizeEmailAddress(value ?? ''))
                    ? null
                    : l10n.mailComposeInvalidRecipient,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _subjectController,
                enabled: !sending,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.mailComposeSubject),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bodyController,
                enabled: !sending,
                minLines: 8,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.mailComposeBody,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
