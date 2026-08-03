// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'request_models.dart';

/// What came back from an attempt to submit.
sealed class SubmissionResult {
  const SubmissionResult();
}

/// The submission was accepted and became a case.
///
/// Nothing produces this yet. It exists so the call site is already written
/// against the shape the real endpoint will return, rather than being changed
/// once it does.
class SubmissionAccepted extends SubmissionResult {
  const SubmissionAccepted(this.request);

  final SubmittedRequest request;
}

/// There is no endpoint to submit to.
///
/// The honest answer in this version — **not** an error, and emphatically not
/// a fake success. The UI states it plainly instead of pretending something
/// was sent.
class SubmissionNotConnected extends SubmissionResult {
  const SubmissionNotConnected();
}

/// The endpoint exists but refused or failed.
class SubmissionFailed extends SubmissionResult {
  const SubmissionFailed(this.reason);

  /// A short technical reason for logging. Never rendered raw to the user and
  /// never carrying the submission's contents.
  final String reason;
}

/// Port: whatever eventually accepts an application or a piece of feedback.
///
/// The boundary exists now, with exactly one implementation that declines to
/// pretend. When a real endpoint is specified, it becomes a second
/// implementation and nothing above this line changes.
abstract interface class RequestGateway {
  Future<SubmissionResult> submit(RequestDraft draft);
}

/// The only implementation there can honestly be today.
///
/// No endpoint has been agreed, so this reports exactly that. Inventing a URL
/// or simulating a success would produce an app that tells students their
/// application was filed when nobody received it.
class NotConnectedRequestGateway implements RequestGateway {
  const NotConnectedRequestGateway();

  @override
  Future<SubmissionResult> submit(RequestDraft draft) async =>
      const SubmissionNotConnected();
}
