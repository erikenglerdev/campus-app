// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:meta/meta.dart';

/// What a grade cell means, kept type-safe instead of a raw string.
enum GradeKind {
  /// A real numeric grade (German 1.0 … 5.0).
  graded,

  /// Passed without a numeric grade ("unbenotet bestanden"). This is also how a
  /// QIS `0,0` together with "bestanden" is represented — NEVER as a 0.0 grade.
  passedUngraded,

  /// No grade recorded.
  none,
}

/// The grade of one exam.
@immutable
class Grade {
  const Grade._(this.kind, this.value);

  const Grade.graded(double value) : this._(GradeKind.graded, value);
  const Grade.passedUngraded() : this._(GradeKind.passedUngraded, null);
  const Grade.none() : this._(GradeKind.none, null);

  final GradeKind kind;

  /// The numeric value — only meaningful when [kind] is [GradeKind.graded].
  final double? value;

  bool get isGraded => kind == GradeKind.graded;
  bool get isPassedUngraded => kind == GradeKind.passedUngraded;
  bool get isEmpty => kind == GradeKind.none;

  @override
  bool operator ==(Object other) =>
      other is Grade && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => isGraded ? 'Grade($value)' : 'Grade(${kind.name})';
}

/// The pass/fail status of an exam row, type-safe with a raw fallback.
enum ExamStatus {
  passed,
  failed,

  /// "Prüfung vorhanden" — an exam exists but is not (yet) a result.
  present,

  /// An unrecognised status; the original text is kept for display.
  unknown,
}

/// One row of the Notenspiegel. Independent of the HTML the parser reads.
@immutable
class GradeEntry {
  const GradeEntry({
    required this.examNumber,
    required this.title,
    required this.grade,
    required this.status,
    required this.statusText,
    this.points,
    this.bonus,
    this.attempt,
    this.examDate,
    this.examiner,
  });

  final String examNumber;
  final String title;
  final Grade grade;
  final ExamStatus status;

  /// The original status text, shown verbatim for [ExamStatus.unknown].
  final String statusText;

  final String? points;

  /// The "Bonus" column — kept as text; labelled factually in the UI.
  final String? bonus;
  final String? attempt;
  final DateTime? examDate;
  final String? examiner;

  @override
  bool operator ==(Object other) =>
      other is GradeEntry &&
      other.examNumber == examNumber &&
      other.title == title &&
      other.grade == grade &&
      other.status == status &&
      other.statusText == statusText &&
      other.points == points &&
      other.bonus == bonus &&
      other.attempt == attempt &&
      other.examDate == examDate &&
      other.examiner == examiner;

  @override
  int get hashCode => Object.hash(
    examNumber,
    title,
    grade,
    status,
    statusText,
    points,
    bonus,
    attempt,
    examDate,
    examiner,
  );
}

/// A whole Notenspiegel — the ordered exam rows.
@immutable
class GradeReport {
  const GradeReport(this.entries);

  final List<GradeEntry> entries;

  bool get isEmpty => entries.isEmpty;
}
