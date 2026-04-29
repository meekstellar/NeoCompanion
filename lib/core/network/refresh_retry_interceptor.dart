import 'package:dio/dio.dart';

import 'esi_constants.dart';

typedef ForceRefresh = Future<String> Function(int characterId);

/// On HTTP 401 for an authenticated request, force-refreshes the access
/// token and retries the request once. Re-failure is surfaced — the UI
/// should treat it as "session expired, re-login required".
class RefreshRetryInterceptor extends Interceptor {
  RefreshRetryInterceptor({required Dio dio, required ForceRefresh forceRefresh})
      : _dio = dio,
        _forceRefresh = forceRefresh;

  final Dio _dio;
  final ForceRefresh _forceRefresh;

  static const _retriedKey = 'refreshRetried';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final options = err.requestOptions;
    final characterId = options.extra[esiCharacterIdKey] as int?;
    final alreadyRetried = options.extra[_retriedKey] == true;

    if (status != 401 || characterId == null || alreadyRetried) {
      return handler.next(err);
    }

    try {
      final fresh = await _forceRefresh(characterId);
      final retried = options.copyWith(
        headers: {...options.headers, 'Authorization': 'Bearer $fresh'},
        extra: {...options.extra, _retriedKey: true},
      );
      final res = await _dio.fetch<dynamic>(retried);
      handler.resolve(res);
    } on DioException catch (e) {
      handler.reject(e);
    } catch (e, st) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          stackTrace: st,
          message: 'Token refresh failed; re-login required',
        ),
      );
    }
  }
}
