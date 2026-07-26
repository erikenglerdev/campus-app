// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import '../../../core/documents/app_document.dart';
import '../../../core/time/clock.dart';
import '../domain/moodle_account.dart';
import '../domain/moodle_announcement.dart';
import '../domain/moodle_api_client.dart';
import '../domain/moodle_assignment.dart';
import '../domain/moodle_cache.dart';
import '../domain/moodle_content.dart';
import '../domain/moodle_course.dart';
import '../domain/moodle_deadline.dart';
import '../domain/moodle_downloader.dart';
import '../domain/moodle_failure.dart';
import '../domain/moodle_repository.dart';
import 'moodle_file_downloader.dart';

/// The one component that ever holds a live Moodle token.
///
/// It composes the API client, the encrypted cache and the secure token store,
/// and it guarantees the core data-integrity rule: an empty or degraded
/// response never destroys the last good cache. A failed fetch throws before any
/// write, and an empty course/deadline list is refused when good data already
/// exists.
class MoodleRepositoryImpl implements MoodleRepository {
  MoodleRepositoryImpl({
    required MoodleApiClient apiClient,
    required MoodleTokenStore tokenStore,
    required MoodleCacheStore cacheStore,
    MoodleFileDownloader? fileDownloader,
    Clock clock = const SystemClock(),
  }) : _api = apiClient,
       _tokens = tokenStore,
       _cache = cacheStore,
       _downloader = fileDownloader ?? MoodleFileDownloaderImpl(),
       // A private field cannot be a named initializing formal, and the public
       // API keeps `clock:`.
       // ignore: prefer_initializing_formals
       _clock = clock;

  final MoodleApiClient _api;
  final MoodleTokenStore _tokens;
  final MoodleCacheStore _cache;
  final MoodleFileDownloader _downloader;
  final Clock _clock;

  @override
  Future<MoodleAccount?> currentAccount() async {
    final MoodleToken? token = await _tokens.read();
    return token?.toAccount();
  }

  @override
  Future<MoodleAccount> connect({
    required String username,
    required String password,
  }) async {
    // 1. Exchange credentials for a token.
    final String tokenValue = await _api.requestToken(
      username: username,
      password: password,
    );
    // 2. Verify the token BEFORE storing anything.
    final MoodleSiteInfo info = await _api.getSiteInfo(tokenValue);
    // 3. Only now persist — the password itself is never stored.
    final MoodleToken token = MoodleToken(
      value: tokenValue,
      userId: info.userId,
      username: info.username ?? username,
      siteName: info.siteName,
    );
    await _tokens.write(token);
    return token.toAccount();
  }

  @override
  Future<void> disconnect() async {
    await _tokens.clear();
    await _cache.clear();
  }

  @override
  Future<List<MoodleCourse>?> cachedCourses() => _cache.readCourses();

  @override
  Future<List<MoodleDeadline>?> cachedDeadlines() => _cache.readDeadlines();

  @override
  Future<MoodleSyncMarks> syncMarks() => _cache.readMarks();

  @override
  Future<void> recordAttempt(DateTime at) async {
    final MoodleSyncMarks marks = await _cache.readMarks();
    await _cache.writeMarks(marks.copyWith(lastAttempt: at));
  }

  @override
  Future<MoodleOverview> refreshOverview() async {
    final MoodleToken token = await _requireToken();

    final List<MoodleCourse> fetchedCourses = await _api.getCourses(
      token: token.value,
      userId: token.userId,
    );
    final List<MoodleDeadline> fetchedDeadlines = await _api
        .getUpcomingDeadlines(token: token.value);

    // Data-integrity guard: an empty response never overwrites good data.
    final List<MoodleCourse>? oldCourses = await _cache.readCourses();
    final List<MoodleDeadline>? oldDeadlines = await _cache.readDeadlines();

    final List<MoodleCourse> effectiveCourses = _keepIfEmpty(
      fetchedCourses,
      oldCourses,
    );
    final List<MoodleDeadline> effectiveDeadlines = _keepIfEmpty(
      fetchedDeadlines,
      oldDeadlines,
    );

    await _cache.writeCourses(effectiveCourses);
    await _cache.writeDeadlines(effectiveDeadlines);

    final DateTime now = _clock.now();
    final MoodleSyncMarks marks = await _cache.readMarks();
    await _cache.writeMarks(marks.copyWith(lastAttempt: now, lastSuccess: now));

    return MoodleOverview(
      courses: effectiveCourses,
      deadlines: effectiveDeadlines,
    );
  }

  @override
  Future<MoodleCourseDetail?> cachedCourseDetail(int courseId) async {
    final MoodleCourse? course = await _findCachedCourse(courseId);
    if (course == null) return null;
    final List<MoodleSection>? sections = await _cache.readSections(courseId);
    if (sections == null) return null; // never loaded
    return MoodleCourseDetail(
      course: course,
      sections: sections,
      assignments:
          await _cache.readAssignments(courseId) ?? const <MoodleAssignment>[],
      announcements:
          await _cache.readAnnouncements(courseId) ??
          const <MoodleAnnouncement>[],
    );
  }

  @override
  Future<MoodleCourseDetail> refreshCourseDetail(int courseId) async {
    final MoodleToken token = await _requireToken();

    final MoodleCourse course =
        await _findCachedCourse(courseId) ??
        MoodleCourse(id: courseId, fullName: 'Kurs $courseId');

    final List<MoodleSection> sections = await _api.getCourseContents(
      token: token.value,
      courseId: courseId,
    );

    final List<MoodleAssignment> assignments = await _api.getAssignments(
      token: token.value,
      courseIds: <int>[courseId],
    );
    final List<MoodleAssignment> withStatus = <MoodleAssignment>[];
    for (final MoodleAssignment a in assignments) {
      final MoodleSubmissionStatus status = await _api.getSubmissionStatus(
        token: token.value,
        assignmentId: a.id,
      );
      withStatus.add(a.withStatus(_flagLate(a, status)));
    }

    final List<MoodleAnnouncement> announcements = await _api.getAnnouncements(
      token: token.value,
      courseId: courseId,
    );

    await _cache.writeSections(courseId, sections);
    await _cache.writeAssignments(courseId, withStatus);
    await _cache.writeAnnouncements(courseId, announcements);

    return MoodleCourseDetail(
      course: course,
      sections: sections,
      assignments: withStatus,
      announcements: announcements,
    );
  }

  @override
  Future<AppDocument> downloadFile(
    MoodleFile file, {
    MoodleDownloadProgress? onProgress,
    MoodleDownloadCancel? cancel,
  }) async {
    final MoodleToken token = await _requireToken();
    return _downloader.download(
      token: token.value,
      fileUrl: file.fileUrl,
      fileName: file.fileName,
      declaredMimeType: file.mimeType,
      declaredSize: file.fileSize,
      onProgress: onProgress,
      cancel: cancel,
    );
  }

  // -------------------------------------------------------------------------

  Future<MoodleToken> _requireToken() async {
    final MoodleToken? token = await _tokens.read();
    if (token == null) {
      throw const MoodleFailure(MoodleFailureKind.tokenExpired);
    }
    return token;
  }

  Future<MoodleCourse?> _findCachedCourse(int courseId) async {
    final List<MoodleCourse>? courses = await _cache.readCourses();
    if (courses == null) return null;
    for (final MoodleCourse c in courses) {
      if (c.id == courseId) return c;
    }
    return null;
  }

  /// Returns [fresh] unless it is empty while [old] holds good data — in which
  /// case the good data is kept (an empty response must not wipe the cache).
  List<T> _keepIfEmpty<T>(List<T> fresh, List<T>? old) {
    if (fresh.isEmpty && old != null && old.isNotEmpty) return old;
    return fresh;
  }

  MoodleSubmissionStatus _flagLate(
    MoodleAssignment assignment,
    MoodleSubmissionStatus status,
  ) {
    final DateTime? due = assignment.dueDate;
    final DateTime? submitted = status.submittedAt;
    final bool late =
        due != null && submitted != null && submitted.isAfter(due);
    return late ? status.copyWith(isLate: true) : status;
  }
}
