import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/core/network/esi_cache.dart';
import 'package:neocompanion/core/network/esi_client.dart';

import 'fake_adapter.dart';

void main() {
  EsiClient buildClient(FakeAdapter adapter, EsiCache cache) {
    final dio = Dio()..httpClientAdapter = adapter;
    return EsiClient.fromCallbacks(
      getValidAccessToken: (_) async => 'access',
      forceRefresh: (_) async => 'access',
      compatibilityDate: '2026-04-29',
      dio: dio,
      cache: cache,
      sleeper: (_) async {},
    );
  }

  test('second identical GET is served from cache without hitting network',
      () async {
    final adapter = FakeAdapter([
      FakeResponse(
        statusCode: 200,
        body: {'hello': 'world'},
        headers: {
          'expires': ['Sat, 31 Dec 2099 23:59:59 GMT'],
        },
      ),
    ]);
    final cache = EsiCache();
    final client = buildClient(adapter, cache);

    final r1 = await client.get<dynamic>('/v1/foo', characterId: 1);
    final r2 = await client.get<dynamic>('/v1/foo', characterId: 1);

    expect(r1.data, {'hello': 'world'});
    expect(r2.data, {'hello': 'world'});
    expect(adapter.requests.length, 1);
    expect(r2.extra['fromCache'], isTrue);
  });

  test('expired entry with ETag triggers If-None-Match and 304 returns cached body',
      () async {
    final adapter = FakeAdapter([
      FakeResponse(
        statusCode: 200,
        body: {'v': 1},
        headers: {
          'expires': ['Mon, 01 Jan 2000 00:00:00 GMT'], // already expired
          'etag': ['"v1"'],
        },
      ),
      FakeResponse(
        statusCode: 304,
        headers: {
          'expires': ['Sat, 31 Dec 2099 23:59:59 GMT'],
          'etag': ['"v1"'],
        },
      ),
    ]);
    final cache = EsiCache();
    final client = buildClient(adapter, cache);

    final r1 = await client.get<dynamic>('/v1/bar', characterId: 7);
    final r2 = await client.get<dynamic>('/v1/bar', characterId: 7);

    expect(r1.data, {'v': 1});
    expect(r2.data, {'v': 1}); // cached body returned despite 304
    expect(r2.extra['fromCache'], isTrue);
    expect(adapter.requests.length, 2);
    expect(adapter.requests[1].headers['If-None-Match'], '"v1"');
  });

  test('different characters cache the same path independently', () async {
    final adapter = FakeAdapter([
      FakeResponse(
        statusCode: 200,
        body: {'who': 'a'},
        headers: {
          'expires': ['Sat, 31 Dec 2099 23:59:59 GMT'],
        },
      ),
      FakeResponse(
        statusCode: 200,
        body: {'who': 'b'},
        headers: {
          'expires': ['Sat, 31 Dec 2099 23:59:59 GMT'],
        },
      ),
    ]);
    final cache = EsiCache();
    final client = buildClient(adapter, cache);

    final ra = await client.get<dynamic>('/v1/me', characterId: 1);
    final rb = await client.get<dynamic>('/v1/me', characterId: 2);
    expect(ra.data, {'who': 'a'});
    expect(rb.data, {'who': 'b'});
    expect(adapter.requests.length, 2);
  });
}
