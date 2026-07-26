// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:meta/meta.dart';

/// A forum announcement (news-forum discussion) within a course.
@immutable
class MoodleAnnouncement {
  const MoodleAnnouncement({
    required this.id,
    required this.courseId,
    required this.subject,
    this.message = '',
    this.authorName,
    this.createdAt,
  });

  final int id;
  final int courseId;
  final String subject;

  /// Safe plain text (no HTML/scripts).
  final String message;

  final String? authorName;
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      other is MoodleAnnouncement &&
      other.id == id &&
      other.courseId == courseId &&
      other.subject == subject &&
      other.message == message &&
      other.authorName == authorName &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, courseId, subject, message, authorName, createdAt);
}
