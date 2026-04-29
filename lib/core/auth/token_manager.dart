import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/secure_key_value_store.dart';
import 'eve_sso_endpoints.dart';
import 'token_set.dart';

class TokenManager {
  TokenManager({
    required SecureKeyValueStore storage,
    required EveSsoEndpoints endpoints,
    required String clientId,
    Dio? dio,
  })  : _storage = storage,
        _endpoints = endpoints,
        _clientId = clientId,
        _dio = dio ?? Dio();

  final SecureKeyValueStore _storage;
  final EveSsoEndpoints _endpoints;
  final String _clientId;
  final Dio _dio;

  static const _indexKey = 'eve_token_index';
  String _tokenKey(int characterId) => 'eve_token.$characterId';

  Future<void> store(TokenSet tokens) async {
    await _storage.write(_tokenKey(tokens.characterId), tokens.encode());
    final ids = await listCharacterIds();
    if (!ids.contains(tokens.characterId)) {
      ids.add(tokens.characterId);
      await _storage.write(_indexKey, jsonEncode(ids));
    }
  }

  Future<TokenSet?> read(int characterId) async {
    final raw = await _storage.read(_tokenKey(characterId));
    if (raw == null) return null;
    return TokenSet.decode(raw);
  }

  Future<void> remove(int characterId) async {
    await _storage.delete(_tokenKey(characterId));
    final ids = await listCharacterIds()..remove(characterId);
    await _storage.write(_indexKey, jsonEncode(ids));
  }

  Future<List<int>> listCharacterIds() async {
    final raw = await _storage.read(_indexKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<int>();
  }

  Future<String> getValidAccessToken(int characterId) async {
    final tokens = await read(characterId);
    if (tokens == null) {
      throw StateError('No tokens for character $characterId');
    }
    if (!tokens.isExpired) return tokens.accessToken;
    final refreshed = await _refresh(tokens);
    await store(refreshed);
    return refreshed.accessToken;
  }

  /// Refresh regardless of local expiry (e.g. when ESI returned 401 even
  /// though our clock thinks the token is still valid). Persists and
  /// returns the new access token.
  Future<String> forceRefresh(int characterId) async {
    final tokens = await read(characterId);
    if (tokens == null) {
      throw StateError('No tokens for character $characterId');
    }
    final refreshed = await _refresh(tokens);
    await store(refreshed);
    return refreshed.accessToken;
  }

  Future<TokenSet> _refresh(TokenSet tokens) async {
    final meta = await _endpoints.metadata();
    final res = await _dio.postUri<Map<String, dynamic>>(
      Uri.parse(meta.tokenEndpoint),
      data: {
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken,
        'client_id': _clientId,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Host': 'login.eveonline.com'},
      ),
    );
    final body = res.data!;
    return tokens.copyWith(
      accessToken: body['access_token'] as String,
      refreshToken: body['refresh_token'] as String? ?? tokens.refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: body['expires_in'] as int)),
    );
  }
}
