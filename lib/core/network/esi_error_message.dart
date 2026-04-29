import 'package:dio/dio.dart';

/// Maps an exception thrown by EsiClient (or any underlying Dio call) to a
/// short user-facing message. Keeps the screens free of `'$e'` strings.
String describeEsiError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status != null) {
      if (status == 401) return 'Session expired — please re-add this character.';
      if (status == 403) return 'Missing scopes for this request.';
      if (status == 420) return 'Rate-limited by ESI. Try again in a minute.';
      if (status >= 500) return 'ESI is having trouble right now. Try again shortly.';
      return 'ESI returned $status.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Check your connection.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return 'TLS certificate problem.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Network error: ${error.message ?? 'unknown'}.';
    }
  }
  return error.toString();
}
