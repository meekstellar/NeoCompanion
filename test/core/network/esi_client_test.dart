import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/core/network/esi_client.dart';

import 'fake_adapter.dart';

void main() {
  EsiClient build({
    required FakeAdapter adapter,
    Future<String> Function(int)? getValid,
    Future<String> Function(int)? forceRefresh,
  }) {
    final dio = Dio()..httpClientAdapter = adapter;
    return EsiClient.fromCallbacks(
      getValidAccessToken: getValid ?? (_) async => 'access-1',
      forceRefresh: forceRefresh ?? (_) async => 'access-2',
      compatibilityDate: '2026-04-29',
      dio: dio,
      sleeper: (_) async {},
    );
  }

  test('attaches bearer token and standard headers', () async {
    final adapter = FakeAdapter([
      FakeResponse(statusCode: 200, body: {'name': 'Alice'}),
    ]);
    final client = build(adapter: adapter);
    final res = await client.get<dynamic>('/v1/foo', characterId: 90000001);
    expect(res.statusCode, 200);
    final req = adapter.requests.single;
    expect(req.headers['Authorization'], 'Bearer access-1');
    expect(req.headers['User-Agent'], contains('NeoCompanion'));
    expect(req.headers['X-Compatibility-Date'], '2026-04-29');
  });

  test('refreshes token and retries once on 401', () async {
    final adapter = FakeAdapter([
      FakeResponse(statusCode: 401),
      FakeResponse(statusCode: 200, body: {'ok': true}),
    ]);
    var current = 'access-1';
    var refreshCalls = 0;
    final client = build(
      adapter: adapter,
      getValid: (_) async => current,
      forceRefresh: (_) async {
        refreshCalls++;
        current = 'access-2';
        return current;
      },
    );

    final res = await client.get<dynamic>('/v1/foo', characterId: 7);
    expect(res.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.requests.length, 2);
    expect(adapter.requests[0].headers['Authorization'], 'Bearer access-1');
    expect(adapter.requests[1].headers['Authorization'], 'Bearer access-2');
  });

  test('does not retry when refresh itself fails', () async {
    final adapter = FakeAdapter([FakeResponse(statusCode: 401)]);
    final client = build(
      adapter: adapter,
      forceRefresh: (_) async => throw StateError('refresh broke'),
    );
    await expectLater(
      client.get<dynamic>('/v1/foo', characterId: 7),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests.length, 1);
  });

  test('retries 420 with exponential backoff up to limit', () async {
    final adapter = FakeAdapter([
      FakeResponse(statusCode: 420),
      FakeResponse(statusCode: 420),
      FakeResponse(statusCode: 200, body: {'ok': true}),
    ]);
    final client = build(adapter: adapter);
    final res = await client.get<dynamic>('/v1/foo', characterId: 1);
    expect(res.statusCode, 200);
    expect(adapter.requests.length, 3);
  });

  test('surfaces 420 after max retries are exhausted', () async {
    final adapter = FakeAdapter(
      List.generate(5, (_) => FakeResponse(statusCode: 420)),
    );
    final client = build(adapter: adapter);
    await expectLater(
      client.get<dynamic>('/v1/foo', characterId: 1),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          420,
        ),
      ),
    );
    // 1 original + 3 retries = 4 calls
    expect(adapter.requests.length, 4);
  });
}
