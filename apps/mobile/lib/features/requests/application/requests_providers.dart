// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/case_document_downloader.dart';
import '../data/encrypted_request_store.dart';
import '../data/feedback_areas_repository.dart';
import '../data/gremio_request_gateway.dart';
import '../data/gremio_status_gateway.dart';
import '../data/locations_repository.dart';
import '../data/requests_api_config.dart';
import '../data/attachment_picker.dart';
import '../domain/application_location.dart';
import '../domain/feedback_area.dart';
import '../domain/request_gateway.dart';
import '../domain/request_store.dart';
import '../domain/status_gateway.dart';

/// Overridable so tests never touch the file system or the keychain.
final Provider<RequestStore> requestStoreProvider = Provider<RequestStore>(
  (Ref ref) => EncryptedRequestStore(),
);

/// A `dio` of its own, deliberately **not** the Campus API client.
///
/// Different host, different timeouts, and — the reason that matters — no
/// shared interceptors: no `LogInterceptor`, no campus auth, nothing that
/// logs or reports may ever see this traffic (CLAUDE.md §2, §3). Every request
/// here carries either an identity document or a bearer-equivalent link.
final Provider<Dio> requestsDioProvider = Provider<Dio>(
  (Ref ref) => Dio(
    BaseOptions(
      connectTimeout: RequestsApiConfig.connectTimeout,
      receiveTimeout: RequestsApiConfig.receiveTimeout,
      validateStatus: (int? status) => status != null && status < 500,
    ),
  ),
);

/// The submission boundary.
///
/// Falls back to the honest "not connected" implementation when the build was
/// not given an HTTPS address, rather than guessing one.
final Provider<RequestGateway> requestGatewayProvider =
    Provider<RequestGateway>(
      (Ref ref) => RequestsApiConfig.isConfigured
          ? GremioRequestGateway(
              dio: ref.watch(requestsDioProvider),
              baseUrl: RequestsApiConfig.baseUrl,
              attachments: ref.watch(attachmentStoreProvider),
            )
          : const NotConnectedRequestGateway(),
    );

final Provider<StatusGateway> statusGatewayProvider = Provider<StatusGateway>(
  (Ref ref) => RequestsApiConfig.isConfigured
      ? GremioStatusGateway(
          dio: ref.watch(requestsDioProvider),
          baseUrl: RequestsApiConfig.baseUrl,
        )
      : const NotConnectedStatusGateway(),
);

final Provider<CaseDocumentDownloader> caseDocumentDownloaderProvider =
    Provider<CaseDocumentDownloader>(
      (Ref ref) => CaseDocumentDownloader(
        dio: ref.watch(requestsDioProvider),
        baseUrl: RequestsApiConfig.baseUrl,
      ),
    );

/// Whether this build knows where to submit.
///
/// A provider rather than a direct read of the compile-time constant, so the
/// screens can be tested in both states.
final Provider<bool> requestsEndpointConfiguredProvider = Provider<bool>(
  (Ref ref) => RequestsApiConfig.isConfigured,
);

final Provider<LocationsRepository> locationsRepositoryProvider =
    Provider<LocationsRepository>(
      (Ref ref) => LocationsRepository(
        dio: ref.watch(requestsDioProvider),
        baseUrl: RequestsApiConfig.baseUrl,
      ),
    );

final Provider<FeedbackAreasRepository> feedbackAreasRepositoryProvider =
    Provider<FeedbackAreasRepository>(
      (Ref ref) => FeedbackAreasRepository(
        dio: ref.watch(requestsDioProvider),
        baseUrl: RequestsApiConfig.baseUrl,
      ),
    );

/// The selectable locations, fetched on demand.
final FutureProvider<List<ApplicationLocation>> applicationLocationsProvider =
    FutureProvider<List<ApplicationLocation>>(
      (Ref ref) => ref.watch(locationsRepositoryProvider).fetch(),
    );

/// The selectable feedback areas, fetched on demand.
final FutureProvider<List<FeedbackArea>> feedbackAreasProvider =
    FutureProvider<List<FeedbackArea>>(
      (Ref ref) => ref.watch(feedbackAreasRepositoryProvider).fetch(),
    );
