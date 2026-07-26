// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A downloaded document to preview in-app — source-agnostic. Mail attachments
/// and Moodle files both map onto this, so the viewer depends on neither.
@immutable
class AppDocument {
  const AppDocument({
    required this.filename,
    required this.mediaType,
    required this.bytes,
    this.sizeBytes,
  });

  final String filename;
  final String mediaType;
  final Uint8List bytes;
  final int? sizeBytes;

  bool get isImage => documentIsImage(mediaType);
  bool get isPdf => documentIsPdf(mediaType, filename);
  bool get isText => documentIsText(mediaType);
}

/// The largest file the app will hold fully in memory for an in-app preview.
/// Larger files are offered as share/open-externally instead.
const int kMaxInMemoryPreviewBytes = 25 * 1024 * 1024;

bool documentIsImage(String mediaType) =>
    mediaType.toLowerCase().startsWith('image/');

bool documentIsPdf(String mediaType, String filename) =>
    mediaType.toLowerCase() == 'application/pdf' ||
    filename.toLowerCase().endsWith('.pdf');

bool documentIsText(String mediaType) =>
    mediaType.toLowerCase().startsWith('text/');

/// A compact human-readable size label (`12 KB`, `1.3 MB`).
String humanFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

const Map<String, String> _extensionTypes = <String, String>{
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'svg': 'image/svg+xml',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'html': 'text/html',
  'htm': 'text/html',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'zip': 'application/zip',
};

/// The MIME type for a file: the [declared] type if usable, else guessed from
/// the filename extension, else a safe generic binary type.
String mediaTypeFor(String filename, {String? declared}) {
  final String d = (declared ?? '').trim();
  if (d.isNotEmpty && d != 'application/octet-stream' && d.contains('/')) {
    return d;
  }
  final int dot = filename.lastIndexOf('.');
  if (dot >= 0 && dot < filename.length - 1) {
    final String ext = filename.substring(dot + 1).toLowerCase();
    final String? type = _extensionTypes[ext];
    if (type != null) return type;
  }
  return d.isNotEmpty ? d : 'application/octet-stream';
}
