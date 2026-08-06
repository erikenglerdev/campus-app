// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:dio/dio.dart';

import '../domain/feedback_area.dart';
import 'requests_api_config.dart';

/// The areas feedback can be addressed to.
///
/// Read straight from the receiving system, like the submission itself. Not
/// kept in the content cache: the list is small, it changes rarely, and a
/// stale entry would route feedback to a board that no longer accepts it.
class FeedbackAreasRepository {
  FeedbackAreasRepository({required Dio dio, required String baseUrl})
    : this._(dio, RequestsApiConfig.stripTrailingSlash(baseUrl.trim()));

  FeedbackAreasRepository._(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  /// Returns the selectable areas.
  ///
  /// An empty list is a legitimate answer — the operator may have deactivated
  /// every area — and the form says so rather than showing an empty picker.
  /// Transport failures are left to throw so the caller's `AsyncValue` can
  /// offer a retry.
  Future<List<FeedbackArea>> fetch() async {
    if (_baseUrl.isEmpty) return const <FeedbackArea>[];

    final Response<dynamic> response = await _dio.get<dynamic>(
      '$_baseUrl${RequestsApiConfig.feedbackAreasPath}',
      options: Options(
        headers: <String, String>{'Accept': 'application/json'},
        receiveTimeout: RequestsApiConfig.receiveTimeout,
      ),
    );

    final dynamic body = response.data;
    if (body is! Map<String, dynamic>) return const <FeedbackArea>[];
    return FeedbackArea.listFrom(body['areas']);
  }
}
