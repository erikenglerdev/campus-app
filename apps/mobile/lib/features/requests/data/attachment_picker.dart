// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/request_models.dart';

/// Port: lets the user pick files to send along with a request.
abstract interface class AttachmentPicker {
  /// Returns the files the user chose, already secured for later use.
  /// An empty list means the picker was cancelled.
  Future<List<RequestAttachment>> pick();

  /// Removes a file this app copied. Never touches the user's original.
  Future<void> discard(RequestAttachment attachment);
}

/// Picks files and **copies them into the app's own directory**.
///
/// Keeping only the path the picker returned would look simpler and break
/// quietly: on both platforms that path can be a temporary cache entry or a
/// content URI that stops resolving once the picker's session ends. A draft is
/// meant to be reopened days later, so an attachment that silently vanishes
/// between sessions would be worse than not offering attachments at all.
///
/// The copy lives in the app's documents directory — not encrypted, because
/// the user chose to attach it to something they intend to send, which is the
/// same category of data as the draft text beside it.
class LocalCopyAttachmentPicker implements AttachmentPicker {
  const LocalCopyAttachmentPicker();

  static const String _folder = 'request_attachments';

  @override
  Future<List<RequestAttachment>> pick() async {
    final List<XFile> chosen = await openFiles();
    if (chosen.isEmpty) return const <RequestAttachment>[];

    final Directory target = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/$_folder',
    );
    await target.create(recursive: true);

    final List<RequestAttachment> kept = <RequestAttachment>[];
    for (final XFile file in chosen) {
      try {
        // Prefixed with a timestamp so two files of the same name can coexist.
        final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
        final String copy = '${target.path}/$stamp-${file.name}';
        await File(file.path).copy(copy);
        kept.add(
          RequestAttachment(
            fileName: file.name,
            path: copy,
            sizeBytes: await File(copy).length(),
          ),
        );
      } catch (_) {
        // One unreadable file must not lose the others.
        continue;
      }
    }
    return kept;
  }

  @override
  Future<void> discard(RequestAttachment attachment) async {
    try {
      final File file = File(attachment.path);
      // Only ever inside our own folder — never a file the user still owns.
      if (file.path.contains('/$_folder/') && file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

/// Overridable so tests never open a platform dialog.
final Provider<AttachmentPicker> attachmentPickerProvider =
    Provider<AttachmentPicker>((Ref ref) => const LocalCopyAttachmentPicker());
