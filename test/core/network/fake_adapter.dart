import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeResponse {
  FakeResponse({
    required this.statusCode,
    Map<String, dynamic>? body,
    Map<String, List<String>>? headers,
  })  : body = body ?? const {},
        headers = headers ?? const {};

  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, List<String>> headers;
}

/// Returns canned responses in the order they were configured. Records
/// every request URL so tests can assert on the call sequence.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this._queue);

  final List<FakeResponse> _queue;
  final List<RequestOptions> requests = [];

  void queueResponse(FakeResponse response) => _queue.add(response);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) {
      throw StateError('FakeAdapter ran out of canned responses');
    }
    final next = _queue.removeAt(0);
    final bytes = utf8.encode(jsonEncode(next.body));
    return ResponseBody.fromBytes(
      bytes,
      next.statusCode,
      headers: {
        'content-type': const ['application/json'],
        ...next.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
