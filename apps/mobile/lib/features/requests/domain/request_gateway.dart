// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'request_models.dart';

/// What came back from an attempt to submit.
///
/// One case per outcome the endpoint documents, because they call for different
/// things from the user: a rejected field can be corrected, a conflict cannot,
/// a rate limit only needs patience, and a network failure should be retried
/// with the *same* key.
sealed class SubmissionResult {
  const SubmissionResult();
}

/// The submission was accepted and became a case.
class SubmissionAccepted extends SubmissionResult {
  const SubmissionAccepted(this.request);

  final SubmittedRequest request;
}

/// No endpoint is configured in this build.
///
/// The honest answer when `REQUESTS_BASE_URL` is empty — **not** an error, and
/// emphatically not a fake success.
class SubmissionNotConnected extends SubmissionResult {
  const SubmissionNotConnected();
}

/// The draft is incomplete or the endpoint refused a field (400 / 422).
class SubmissionRejected extends SubmissionResult {
  const SubmissionRejected({
    required this.message,
    this.issues = const <String>[],
  });

  /// The endpoint's own wording. It is written for the applicant and is more
  /// specific than anything the app could say from the status code alone.
  final String message;

  /// Field-level hints, already flattened to text.
  final List<String> issues;
}

/// The same key was used for a different application (409).
///
/// Not retryable: sending again cannot help, and sending with a fresh key
/// would file a second application. Needs a decision from the user.
class SubmissionConflict extends SubmissionResult {
  const SubmissionConflict();
}

/// A file, or the whole request, exceeded the size limit (413).
class SubmissionTooLarge extends SubmissionResult {
  const SubmissionTooLarge();
}

/// Rate limited (429).
class SubmissionRateLimited extends SubmissionResult {
  const SubmissionRateLimited({this.retryAfter});

  final Duration? retryAfter;
}

/// Reached nobody: no network, DNS failure, timeout.
///
/// Distinct from [SubmissionFailed] because it is the case the idempotency key
/// exists for — the application may or may not have been filed, and retrying
/// with the same key is exactly the right move.
class SubmissionUnreachable extends SubmissionResult {
  const SubmissionUnreachable();
}

/// The endpoint answered, but with something unusable.
class SubmissionFailed extends SubmissionResult {
  const SubmissionFailed(this.reason);

  /// A short technical reason for logging. Never rendered raw to the user and
  /// never carrying the submission's contents or the status link.
  final String reason;
}

/// Port: whatever accepts an application.
abstract interface class RequestGateway {
  Future<SubmissionResult> submit(RequestDraft draft);
}

/// Used when no endpoint is configured for this build.
///
/// Inventing a URL or simulating a success would produce an app that tells
/// students their application was filed when nobody received it.
class NotConnectedRequestGateway implements RequestGateway {
  const NotConnectedRequestGateway();

  @override
  Future<SubmissionResult> submit(RequestDraft draft) async =>
      const SubmissionNotConnected();
}
