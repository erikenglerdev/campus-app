// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_account_controller.dart';
import '../application/mail_compose_controller.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_gateway.dart';
import '../domain/mail_message.dart';
import 'compose_draft.dart';
import 'mail_error_messages.dart';
import 'recipient_field.dart';

/// Compose a text-only message. The sender is always the signed-in account
/// address — there is no From field to edit. A send in flight disables the
/// button, and the controller ignores a second trigger, so a message is never
/// sent twice.
///
/// The screen closes the instant the SMTP submission succeeds; storing the Sent
/// copy happens in the background so the user is never left on a spinner after
/// the message has actually left.
class MailComposeScreen extends ConsumerStatefulWidget {
  const MailComposeScreen({this.draft, super.key});

  /// Optional pre-filled content (a reply or reply-all).
  final ComposeDraft? draft;

  @override
  ConsumerState<MailComposeScreen> createState() => _MailComposeScreenState();
}

class _MailComposeScreenState extends ConsumerState<MailComposeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _toController;
  late final TextEditingController _ccController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    final ComposeDraft draft = widget.draft ?? const ComposeDraft();
    _toController = TextEditingController(text: draft.to.join(', '));
    _ccController = TextEditingController(text: draft.cc.join(', '));
    _subjectController = TextEditingController(text: draft.subject);
    _bodyController = TextEditingController(text: draft.body);
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Splits a recipient field on commas/semicolons into trimmed addresses.
  List<String> _parseRecipients(String raw) => raw
      .split(RegExp(r'[,;]'))
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList();

  Future<void> _send() async {
    final AppLocalizations l10n = context.l10n;
    if (ref.read(mailComposeControllerProvider)) return; // already sending
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final OutgoingMessage message = OutgoingMessage(
      to: _parseRecipients(_toController.text),
      cc: _parseRecipients(_ccController.text),
      subject: _subjectController.text,
      text: _bodyController.text,
    );

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final MailComposeController controller = ref.read(
      mailComposeControllerProvider.notifier,
    );

    try {
      final bool sent = await controller.send(message);
      if (!sent) return; // a concurrent send was already running
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailComposeSent)));
      if (navigator.canPop()) navigator.pop();

      // Store the Sent copy in the background. The message has already left, so
      // a failure here is only a gentle hint — it never blocks or re-sends.
      unawaited(
        controller.appendSentCopy(message).then((SentCopyResult result) {
          if (result != SentCopyResult.appended) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.mailComposeSentNoCopy)),
            );
          }
        }),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(mailFailureMessage(l10n, error))),
      );
    }
  }

  String? _validateTo(String? value) {
    final List<String> recipients = _parseRecipients(value ?? '');
    if (recipients.isEmpty ||
        recipients.any((String r) => !isValidEmailAddress(r))) {
      return context.l10n.mailComposeInvalidRecipient;
    }
    return null;
  }

  String? _validateCc(String? value) {
    final List<String> recipients = _parseRecipients(value ?? '');
    if (recipients.any((String r) => !isValidEmailAddress(r))) {
      return context.l10n.mailComposeInvalidRecipient;
    }
    return null;
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
            padding: EdgeInsets.all(context.metrics.screenPadding),
            children: <Widget>[
              if (email != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.mailComposeFrom(email),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              RecipientAutocompleteField(
                controller: _toController,
                enabled: !sending,
                label: l10n.mailComposeTo,
                helperText: l10n.mailComposeRecipientsHint,
                icon: Icons.alternate_email,
                validator: _validateTo,
              ),
              const SizedBox(height: AppSpacing.md),
              RecipientAutocompleteField(
                controller: _ccController,
                enabled: !sending,
                label: l10n.mailComposeCc,
                icon: Icons.group_outlined,
                validator: _validateCc,
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
