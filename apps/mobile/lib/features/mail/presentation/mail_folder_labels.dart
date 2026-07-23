// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../domain/mail_folder.dart';

/// A localized label for a folder: special-use roles get a translated name,
/// everything else keeps the server-provided name.
String folderLabel(AppLocalizations l10n, MailFolder folder) =>
    switch (folder.role) {
      MailFolderRole.inbox => l10n.mailFolderInbox,
      MailFolderRole.sent => l10n.mailFolderSent,
      MailFolderRole.drafts => l10n.mailFolderDrafts,
      MailFolderRole.trash => l10n.mailFolderTrash,
      MailFolderRole.junk => l10n.mailFolderJunk,
      MailFolderRole.archive => l10n.mailFolderArchive,
      MailFolderRole.plain => folder.name,
    };

/// An icon matching a folder's role.
IconData folderIcon(MailFolderRole role) => switch (role) {
  MailFolderRole.inbox => Icons.inbox_outlined,
  MailFolderRole.sent => Icons.send_outlined,
  MailFolderRole.drafts => Icons.drafts_outlined,
  MailFolderRole.trash => Icons.delete_outline,
  MailFolderRole.junk => Icons.report_outlined,
  MailFolderRole.archive => Icons.archive_outlined,
  MailFolderRole.plain => Icons.folder_outlined,
};
