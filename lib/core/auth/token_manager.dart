import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/secure_key_value_store.dart';
import 'eve_sso_endpoints.dart';
import 'token_set.dart';

class TokenRefreshException implements Exception {
  TokenRefreshException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() =>
      'TokenRefreshException: $message${cause == null ? '' : ' ($cause)'}';
}

class TokenManager {
  TokenManager({
    required SecureKeyValueStore storage,
    required EveSsoEndpoints endpoints,
    required String clientId,
    Dio? dio,
  })  : _storage = storage,
        _endpoints = endpoints,
        _clientId = clientId,
        _dio = dio ?? _defaultDio();

  static Dio _defaultDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 10),
      ));

  final SecureKeyValueStore _storage;
  final EveSsoEndpoints _endpoints;
  final String _clientId;
  final Dio _dio;

  // EVE SSO rotates refresh tokens — concurrent refreshes for the same
  // character would invalidate each other. Coalesce them.
  final Map<int, Future<TokenSet>> _inflight = {};
  // Serializes index read-modify-write to avoid lost updates when multiple
  // characters store/remove concurrently.
  Future<void> _indexLock = Future.value();

  static const _indexKey = 'eve_token_index';
  String _tokenKey(int characterId) => 'eve_token.$characterId';

  Future<T> _runIndex<T>(Future<T> Function() body) {
    final next = _indexLock.then((_) => body());
    _indexLock = next.then((_) => null, onError: (_) => null);
    return next;
  }

  Future<void> store(TokenSet tokens) async {
    await _storage.write(_tokenKey(tokens.characterId), tokens.encode());
    await _runIndex(() async {
      final ids = await _readIndex();
      if (!ids.contains(tokens.characterId)) {
        ids.add(tokens.characterId);
        await _storage.write(_indexKey, jsonEncode(ids));
      }
    });
  }

  Future<TokenSet?> read(int characterId) async {
    final raw = await _storage.read(_tokenKey(characterId));
    if (raw == null) return null;
    return TokenSet.decode(raw);
  }

  Future<void> remove(int characterId) async {
    await _storage.delete(_tokenKey(characterId));
    await _runIndex(() async {
      final ids = await _readIndex()
        ..remove(characterId);
      await _storage.write(_indexKey, jsonEncode(ids));
    });
  }

  Future<List<int>> listCharacterIds() => _runIndex(_readIndex);

  Future<List<int>> _readIndex() async {
    final raw = await _storage.read(_indexKey);
    if (raw == null) return <int>[];
    try {
      return (jsonDecode(raw) as List).cast<int>().toList();
    } catch (_) {
      return <int>[];
    }
  }

  Future<String> getValidAccessToken(int characterId) async {
    final tokens = await read(characterId);
    if (tokens == null) {
      throw StateError('No tokens for character $characterId');
    }
    if (!tokens.isExpired) return tokens.accessToken;
    final refreshed = await _refreshDeduped(tokens);
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
    final refreshed = await _refreshDeduped(tokens);
    return refreshed.accessToken;
  }

  Future<TokenSet> _refreshDeduped(TokenSet tokens) {
    final pending = _inflight[tokens.characterId];
    if (pending != null) return pending;
    final future = _refresh(tokens).then((refreshed) async {
      await store(refreshed);
      return refreshed;
    }).whenComplete(() {
      _inflight.remove(tokens.characterId);
    });
    _inflight[tokens.characterId] = future;
    return future;
  }

  Future<TokenSet> _refresh(TokenSet tokens) async {
    final meta = await _endpoints.metadata();
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.postUri<Map<String, dynamic>>(
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
    } on DioException catch (e) {
      throw TokenRefreshException('Refresh request failed', e);
    }

    final body = res.data;
    if (body == null) {
      throw TokenRefreshException('Refresh response had empty body');
    }
    final access = body['access_token'];
    final expiresIn = body['expires_in'];
    if (access is! String || expiresIn is! int) {
      throw TokenRefreshException(
          'Refresh response missing access_token/expires_in');
    }
    final refreshTokenRaw = body['refresh_token'];
    return tokens.copyWith(
      accessToken: access,
      refreshToken:
          refreshTokenRaw is String ? refreshTokenRaw : tokens.refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }
}
