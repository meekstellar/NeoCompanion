import 'package:dio/dio.dart';

import '../auth/token_manager.dart';
import 'esi_constants.dart';

/// Thin Dio wrapper that handles cross-cutting ESI concerns: User-Agent,
/// X-Compatibility-Date and bearer auth. Cache, error-limit and refresh
/// retry are layered in subsequent commits.
class EsiClient {
  EsiClient({
    required TokenManager tokens,
    required String compatibilityDate,
    Dio? dio,
  })  : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = esiBaseUrl
      ..headers[Headers.acceptHeader] = 'application/json'
      ..headers['User-Agent'] = esiUserAgent
      ..headers['X-Compatibility-Date'] = compatibilityDate;
    _dio.interceptors.add(_AuthInterceptor(tokens));
  }

  final Dio _dio;

  /// Issues a GET request. If [characterId] is provided, the request will
  /// be authenticated with that character's access token.
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

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokens);

  final TokenManager _tokens;

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
      final token = await _tokens.getValidAccessToken(characterId);
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
