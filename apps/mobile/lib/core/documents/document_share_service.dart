// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:share_plus/share_plus.dart';

import 'app_document.dart';

/// Shares a downloaded document through the OS share sheet. The in-memory bytes
/// are written to a temporary file by share_plus with the correct name.
class DocumentShareService {
  const DocumentShareService();

  Future<void> share(AppDocument document) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(document.bytes, mimeType: document.mediaType),
        ],
        fileNameOverrides: <String>[document.filename],
      ),
    );
  }
}
