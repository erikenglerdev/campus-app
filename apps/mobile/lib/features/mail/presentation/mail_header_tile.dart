// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/mail_message.dart';

/// One row in a message list (inbox or search results): sender, subject, date
/// and an attachment marker. Tapping opens the message in the selected mailbox.
class MailHeaderTile extends StatelessWidget {
  const MailHeaderTile({required this.header, required this.locale, super.key});

  final MailMessageHeader header;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final FontWeight weight = header.isSeen
        ? FontWeight.normal
        : FontWeight.w700;
    final String sender = header.from.display.trim().isEmpty
        ? l10n.mailUnknownSender
        : header.from.display;
    final String subject = header.subject.trim().isEmpty
        ? l10n.mailNoSubject
        : header.subject;

    return ListTile(
      leading: header.isSeen
          ? const Icon(Icons.mail_outline)
          : const Icon(Icons.markunread),
      title: Text(
        sender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge?.copyWith(fontWeight: weight),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: weight),
          ),
          if (header.date != null)
            Text(
              AppDateFormats.dateTime(header.date!, locale),
              style: text.bodySmall,
            ),
        ],
      ),
      trailing: header.hasAttachments
          ? const Icon(Icons.attach_file, size: AppSizes.icon)
          : null,
      isThreeLine: header.date != null,
      onTap: () => context.pushNamed(
        AppRoutes.mailMessageName,
        pathParameters: <String, String>{'id': header.id},
      ),
    );
  }
}
