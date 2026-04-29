import 'package:dio/dio.dart';

import '../auth/token_manager.dart';
import 'error_limit_interceptor.dart';
import 'esi_constants.dart';
import 'refresh_retry_interceptor.dart';

/// Thin Dio wrapper that handles cross-cutting ESI concerns: User-Agent,
/// X-Compatibility-Date, bearer auth, refresh-on-401 and ESI's error
/// limit (X-ESI-Error-Limit-* and HTTP 420). Caching lands separately.
class EsiClient {
  EsiClient({
    required TokenManager tokens,
    required String compatibilityDate,
    Dio? dio,
    Sleeper sleeper = _defaultSleep,
  }) : this.fromCallbacks(
          getValidAccessToken: tokens.getValidAccessToken,
          forceRefresh: tokens.forceRefresh,
          compatibilityDate: compatibilityDate,
          dio: dio,
          sleeper: sleeper,
        );

  EsiClient.fromCallbacks({
    required Future<String> Function(int) getValidAccessToken,
    required Future<String> Function(int) forceRefresh,
    required String compatibilityDate,
    Dio? dio,
    Sleeper sleeper = _defaultSleep,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = esiBaseUrl
      ..headers[Headers.acceptHeader] = 'application/json'
      ..headers['User-Agent'] = esiUserAgent
      ..headers['X-Compatibility-Date'] = compatibilityDate;
    _dio.interceptors.add(_AuthInterceptor(getValidAccessToken));
    _dio.interceptors
        .add(RefreshRetryInterceptor(dio: _dio, forceRefresh: forceRefresh));
    _dio.interceptors.add(ErrorLimitInterceptor(dio: _dio, sleeper: sleeper));
  }

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    int? characterId,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: {esiCharacterIdKey: characterId}),
    );
  }
}

Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._getToken);

  final Future<String> Function(int characterId) _getToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final characterId = options.extra[esiCharacterIdKey] as int?;
    if (characterId == null) {
      return handler.next(options);
    }
    try {
      final token = await _getToken(characterId);
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (e, st) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          stackTrace: st,
          message: 'Failed to obtain access token for character $characterId',
        ),
      );
    }
  }
}
