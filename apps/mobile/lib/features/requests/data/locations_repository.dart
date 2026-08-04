// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:dio/dio.dart';

import '../domain/application_location.dart';
import 'requests_api_config.dart';

/// The places an application can be addressed to.
///
/// Read straight from the receiving system, like the submission itself. The
/// list is not cached in the content cache: it is small, it changes rarely,
/// and a stale entry would route an application to a board that no longer
/// accepts it.
class LocationsRepository {
  LocationsRepository({required Dio dio, required String baseUrl})
    : this._(dio, RequestsApiConfig.stripTrailingSlash(baseUrl.trim()));

  LocationsRepository._(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  /// Returns the selectable locations.
  ///
  /// An empty list is a legitimate answer — the operator may have deactivated
  /// every location — and is not distinguishable from "nothing configured"
  /// here on purpose: both mean the user cannot pick one, and the UI says so
  /// once. Throwing on transport failure is left to the caller's `AsyncValue`.
  Future<List<ApplicationLocation>> fetch() async {
    if (_baseUrl.isEmpty) return const <ApplicationLocation>[];

    final Response<dynamic> response = await _dio.get<dynamic>(
      '$_baseUrl${RequestsApiConfig.locationsPath}',
      options: Options(
        headers: <String, String>{'Accept': 'application/json'},
        receiveTimeout: RequestsApiConfig.receiveTimeout,
      ),
    );

    final dynamic body = response.data;
    if (body is! Map<String, dynamic>) return const <ApplicationLocation>[];
    return ApplicationLocation.listFrom(body['locations']);
  }
}
