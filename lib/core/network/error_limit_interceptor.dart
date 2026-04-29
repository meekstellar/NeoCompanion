import 'dart:math';

import 'package:dio/dio.dart';

typedef Sleeper = Future<void> Function(Duration);

Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

/// Honours ESI's per-IP error window:
///  * Reads `X-ESI-Error-Limit-Remain` / `X-ESI-Error-Limit-Reset` from every
///    response and pauses outgoing requests once the remaining budget is
///    too low to risk further bans.
///  * Retries 420 ("error-limited") responses with exponential backoff,
///    up to [maxRetries] times.
class ErrorLimitInterceptor extends Interceptor {
  ErrorLimitInterceptor({
    required Dio dio,
    this.lowWatermark = 20,
    this.maxRetries = 3,
    Sleeper sleeper = _defaultSleep,
  })  : _dio = dio,
        _sleep = sleeper;

  final Dio _dio;
  final int lowWatermark;
  final int maxRetries;
  final Sleeper _sleep;

  int? _remaining;
  DateTime? _resetAt;

  static const _retryKey = 'errorLimitRetries';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final remaining = _remaining;
    final resetAt = _resetAt;
    if (remaining != null &&
        resetAt != null &&
        remaining <= lowWatermark &&
        DateTime.now().isBefore(resetAt)) {
      await _sleep(resetAt.difference(DateTime.now()));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _ingest(response.headers);
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response != null) _ingest(response.headers);

    if (response?.statusCode == 420) {
      final attempts = (err.requestOptions.extra[_retryKey] as int? ?? 0) + 1;
      if (attempts <= maxRetries) {
        await _sleep(Duration(seconds: pow(2, attempts).toInt()));
        final retried = err.requestOptions.copyWith(
          extra: {...err.requestOptions.extra, _retryKey: attempts},
        );
        try {
          final res = await _dio.fetch<dynamic>(retried);
          handler.resolve(res);
          return;
        } on DioException catch (e) {
          handler.reject(e);
          return;
        }
      }
    }
    handler.next(err);
  }

  void _ingest(Headers headers) {
    final remain = headers.value('x-esi-error-limit-remain');
    final reset = headers.value('x-esi-error-limit-reset');
    if (remain != null) _remaining = int.tryParse(remain);
    if (reset != null) {
      final secs = int.tryParse(reset);
      if (secs != null) _resetAt = DateTime.now().add(Duration(seconds: secs));
    }
  }
}
