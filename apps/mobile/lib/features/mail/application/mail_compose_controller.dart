// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_gateway.dart';
import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_providers.dart';

/// Drives a single send. Guards against double submission and never retries
/// automatically when the outcome is unclear.
class MailComposeController extends Notifier<bool> {
  @override
  bool build() => false; // false = idle, true = sending

  Future<SendOutcome?> send({
    required String to,
    required String subject,
    required String text,
  }) async {
    if (state) return null; // already sending — ignore the second trigger
    state = true;
    try {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      final outcome = await ref
          .read(mailGatewayProvider)
          .send(
            credentials,
            OutgoingMessage(to: to.trim(), subject: subject, text: text),
          );
      return outcome;
    } finally {
      state = false;
    }
  }
}

final NotifierProvider<MailComposeController, bool>
mailComposeControllerProvider = NotifierProvider<MailComposeController, bool>(
  MailComposeController.new,
);
