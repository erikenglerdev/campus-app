// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'request_models.dart';

/// Port: local, on-device persistence for drafts and submitted cases.
///
/// Drafts are user-authored data, not a cache — nothing here is ever evicted
/// to make room.
abstract interface class RequestStore {
  Future<List<RequestDraft>> readDrafts();
  Future<void> writeDrafts(List<RequestDraft> drafts);
}

/// A volatile store, used as a safe fallback and in tests.
class InMemoryRequestStore implements RequestStore {
  List<RequestDraft> _drafts = const <RequestDraft>[];

  @override
  Future<List<RequestDraft>> readDrafts() async =>
      List<RequestDraft>.of(_drafts);

  @override
  Future<void> writeDrafts(List<RequestDraft> drafts) async =>
      _drafts = List<RequestDraft>.of(drafts);
}
