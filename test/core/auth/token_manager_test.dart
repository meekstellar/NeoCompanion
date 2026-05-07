import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:neocompanion/core/auth/eve_sso_endpoints.dart';
import 'package:neocompanion/core/auth/token_manager.dart';
import 'package:neocompanion/core/auth/token_set.dart';
import 'package:neocompanion/core/storage/secure_key_value_store.dart';

import '../network/fake_adapter.dart';

class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

class _StubEndpoints implements EveSsoEndpoints {
  _StubEndpoints(this._tokenEndpoint);
  final String _tokenEndpoint;

  @override
  Future<EveSsoMetadata> metadata() async => EveSsoMetadata(
        issuer: 'https://login.eveonline.com',
        authorizationEndpoint: 'https://login.eveonline.com/v2/oauth/authorize',
        tokenEndpoint: _tokenEndpoint,
        revocationEndpoint: 'https://login.eveonline.com/v2/oauth/revoke',
        jwksUri: 'https://login.eveonline.com/oauth/jwks',
      );

  @override
  Future<JsonWebKeyStore> keyStore() async => JsonWebKeyStore();
}

void main() {
  late _InMemoryStore storage;
  late TokenManager manager;
  late FakeAdapter adapter;

  TokenSet sample({
    int id = 90000001,
    DateTime? expiresAt,
    String access = 'old-access',
    String refresh = 'old-refresh',
  }) =>
      TokenSet(
        characterId: id,
        characterName: 'Meek Stellar',
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
        scopes: const ['publicData'],
      );

  setUp(() {
    storage = _InMemoryStore();
    adapter = FakeAdapter([]);
    final dio = Dio()..httpClientAdapter = adapter;
    manager = TokenManager(
      storage: storage,
      endpoints: _StubEndpoints('https://login.eveonline.com/v2/oauth/token'),
      clientId: 'test-client',
      dio: dio,
    );
  });

  test('store persists token and registers character in the index', () async {
    await manager.store(sample());
    expect(await manager.read(90000001), isNotNull);
    expect(await manager.listCharacterIds(), [90000001]);
  });

  test('store de-duplicates the index when called twice for the same character',
      () async {
    await manager.store(sample());
    await manager.store(sample(access: 'new'));
    expect(await manager.listCharacterIds(), [90000001]);
    expect((await manager.read(90000001))!.accessToken, 'new');
  });

  test('remove deletes both the token blob and the index entry', () async {
    await manager.store(sample());
    await manager.store(sample(id: 90000002));
    await manager.remove(90000001);
    expect(await manager.read(90000001), isNull);
    expect(await manager.listCharacterIds(), [90000002]);
  });

  test('getValidAccessToken returns the cached token when not expired',
      () async {
    await manager.store(sample(access: 'still-good'));
    final token = await manager.getValidAccessToken(90000001);
    expect(token, 'still-good');
    expect(adapter.requests, isEmpty); // no refresh call made
  });

  test('getValidAccessToken refreshes when token is expired', () async {
    await manager.store(sample(
      access: 'expired',
      refresh: 'refresh-1',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ));
    adapter.queueResponse(FakeResponse(statusCode: 200, body: {
      'access_token': 'fresh-access',
      'refresh_token': 'refresh-2',
      'expires_in': 1200,
    }));

    final token = await manager.getValidAccessToken(90000001);
    expect(token, 'fresh-access');
    final stored = await manager.read(90000001);
    expect(stored!.accessToken, 'fresh-access');
    expect(stored.refreshToken, 'refresh-2');
    expect(adapter.requests.single.uri.toString(),
        'https://login.eveonline.com/v2/oauth/token');
  });

  test('forceRefresh ignores local expiry and replaces stored token',
      () async {
    await manager.store(sample(access: 'still-good'));
    adapter.queueResponse(FakeResponse(statusCode: 200, body: {
      'access_token': 'fresh-access',
      'expires_in': 1200,
    }));
    final token = await manager.forceRefresh(90000001);
    expect(token, 'fresh-access');
    final stored = await manager.read(90000001);
    expect(stored!.accessToken, 'fresh-access');
    // refresh_token absent in response — keep the previous one
    expect(stored.refreshToken, 'old-refresh');
  });

  test('getValidAccessToken throws StateError when character is unknown',
      () async {
    expect(
      () => manager.getValidAccessToken(123),
      throwsA(isA<StateError>()),
    );
  });

  test('concurrent refreshes for the same character coalesce into one request',
      () async {
    await manager.store(sample(
      access: 'expired',
      refresh: 'refresh-1',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ));
    adapter.queueResponse(FakeResponse(statusCode: 200, body: {
      'access_token': 'fresh-access',
      'refresh_token': 'refresh-2',
      'expires_in': 1200,
    }));

    final results = await Future.wait([
      manager.forceRefresh(90000001),
      manager.forceRefresh(90000001),
      manager.forceRefresh(90000001),
    ]);

    expect(results, ['fresh-access', 'fresh-access', 'fresh-access']);
    // Only ONE refresh hit the network — the others reused the in-flight future.
    expect(adapter.requests, hasLength(1));
  });
}
