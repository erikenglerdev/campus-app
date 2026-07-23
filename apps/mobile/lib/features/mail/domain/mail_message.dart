// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:meta/meta.dart';

/// A single mailbox address as shown in the UI.
@immutable
class MailAddress {
  const MailAddress({required this.email, this.name});

  final String email;
  final String? name;

  /// What the list and detail views show: the name if present, else the email.
  String get display =>
      (name != null && name!.trim().isNotEmpty) ? name! : email;
}

/// Lightweight header for the inbox list. No body, no attachments downloaded.
@immutable
class MailMessageHeader {
  const MailMessageHeader({
    required this.id,
    required this.subject,
    required this.from,
    required this.date,
    required this.isSeen,
    required this.hasAttachments,
  });

  /// Stable per-mailbox identifier (the IMAP UID as a string). Opaque to the UI.
  final String id;
  final String subject;
  final MailAddress from;
  final DateTime? date;
  final bool isSeen;
  final bool hasAttachments;
}

/// Full message for the detail view.
@immutable
class MailMessageDetail {
  const MailMessageDetail({
    required this.id,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.body,
    required this.hasUnsupportedAttachments,
  });

  final String id;
  final String subject;
  final MailAddress from;
  final List<MailAddress> to;
  final DateTime? date;

  /// Already reduced to safe plain text by the gateway: text/plain preferred,
  /// HTML sanitised to text. Never HTML, never a WebView payload.
  final String body;

  /// True when the message carries attachments, which the MVP does not open.
  final bool hasUnsupportedAttachments;
}

/// An outgoing plain-text message.
@immutable
class OutgoingMessage {
  const OutgoingMessage({
    required this.to,
    required this.subject,
    required this.text,
  });

  final String to;
  final String subject;
  final String text;
}
