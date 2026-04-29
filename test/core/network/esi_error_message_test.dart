import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/core/network/esi_error_message.dart';

void main() {
  RequestOptions opts() => RequestOptions(path: '/x');

  test('401 maps to session-expired wording', () {
    final e = DioException(
      requestOptions: opts(),
      response: Response(requestOptions: opts(), statusCode: 401),
    );
    expect(describeEsiError(e), contains('Session expired'));
  });

  test('420 mentions rate limiting', () {
    final e = DioException(
      requestOptions: opts(),
      response: Response(requestOptions: opts(), statusCode: 420),
    );
    expect(describeEsiError(e), contains('Rate-limited'));
  });

  test('5xx mentions ESI trouble', () {
    final e = DioException(
      requestOptions: opts(),
      response: Response(requestOptions: opts(), statusCode: 503),
    );
    expect(describeEsiError(e).toLowerCase(), contains('esi'));
  });

  test('connection error mentions internet', () {
    final e = DioException(
      requestOptions: opts(),
      type: DioExceptionType.connectionError,
    );
    expect(describeEsiError(e).toLowerCase(), contains('internet'));
  });

  test('timeout mentions timeout', () {
    final e = DioException(
      requestOptions: opts(),
      type: DioExceptionType.connectionTimeout,
    );
    expect(describeEsiError(e).toLowerCase(), contains('timeout'));
  });

  test('non-Dio falls back to toString', () {
    expect(describeEsiError('boom'), 'boom');
  });
}
