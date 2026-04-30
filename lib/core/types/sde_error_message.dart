import 'package:dio/dio.dart';

import 'prebuilt_sde_fetcher.dart';

/// User-facing description of an error from the SDE update pipeline.
/// Distinct from `describeEsiError` because the SDE pipeline talks to
/// the GitHub Releases CDN, not ESI — so an ESI-flavoured "ESI
/// returned 404" message is misleading when the actual cause is "no
/// release has been published yet".
String describeSdeError(Object error) {
  if (error is PrebuiltSdeException) {
    return error.message;
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 404) {
      return 'No prebuilt database has been published yet. '
          'Please wait for the next CI run or contact the developer.';
    }
    if (status != null && status >= 500) {
      return 'GitHub is having trouble right now. Try again shortly.';
    }
    if (status != null) {
      return 'Download failed (HTTP $status).';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Check your connection.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.cancel:
        return 'Download cancelled.';
      case DioExceptionType.badCertificate:
        return 'TLS certificate problem.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Network error: ${error.message ?? 'unknown'}.';
    }
  }
  return error.toString();
}
