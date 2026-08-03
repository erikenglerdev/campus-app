// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_request_store.dart';
import '../domain/request_gateway.dart';
import '../domain/request_models.dart';
import '../domain/request_store.dart';

/// Overridable so tests never touch the file system.
final Provider<RequestStore> requestStoreProvider = Provider<RequestStore>(
  (Ref ref) => HiveRequestStore(),
);

/// The submission boundary.
///
/// One implementation today, which declines to pretend. When an endpoint is
/// agreed, this override is the only line that changes.
final Provider<RequestGateway> requestGatewayProvider =
    Provider<RequestGateway>((Ref ref) => const NotConnectedRequestGateway());

/// Locally stored drafts, newest first.
class RequestsController extends AsyncNotifier<List<RequestDraft>> {
  RequestStore get _store => ref.read(requestStoreProvider);

  @override
  Future<List<RequestDraft>> build() async =>
      _sorted(await _store.readDrafts());

  static List<RequestDraft> _sorted(List<RequestDraft> drafts) =>
      drafts.toList()..sort(
        (RequestDraft a, RequestDraft b) => b.updatedAt.compareTo(a.updatedAt),
      );

  RequestDraft? byId(String id) {
    for (final RequestDraft draft in state.value ?? const <RequestDraft>[]) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  /// Creates an empty draft of [kind] and returns it.
  ///
  /// Not persisted yet: an editor the user opens and immediately leaves should
  /// not litter the list with blanks. [save] is what writes.
  RequestDraft create(RequestKind kind, {required DateTime now}) =>
      RequestDraft(
        id: 'draft-${now.microsecondsSinceEpoch}',
        kind: kind,
        createdAt: now,
        updatedAt: now,
      );

  /// Inserts or replaces a draft.
  ///
  /// A draft that is still completely blank is *removed* instead of stored —
  /// leaving the editor without typing anything should leave no trace.
  Future<void> save(RequestDraft draft, {required DateTime now}) async {
    final List<RequestDraft> next = (state.value ?? const <RequestDraft>[])
        .where((RequestDraft d) => d.id != draft.id)
        .toList();
    if (!draft.isEmpty) {
      next.add(draft.copyWith(updatedAt: now));
    }
    await _persist(next);
  }

  Future<void> delete(String id) async {
    final List<RequestDraft> next = (state.value ?? const <RequestDraft>[])
        .where((RequestDraft d) => d.id != id)
        .toList();
    await _persist(next);
  }

  /// Attempts to submit. Returns whatever the gateway says — this method
  /// never invents a result of its own.
  Future<SubmissionResult> submit(RequestDraft draft) =>
      ref.read(requestGatewayProvider).submit(draft);

  Future<void> _persist(List<RequestDraft> drafts) async {
    final List<RequestDraft> sorted = _sorted(drafts);
    state = AsyncData<List<RequestDraft>>(sorted);
    await _store.writeDrafts(sorted);
  }
}

final AsyncNotifierProvider<RequestsController, List<RequestDraft>>
requestsProvider =
    AsyncNotifierProvider<RequestsController, List<RequestDraft>>(
      RequestsController.new,
    );
