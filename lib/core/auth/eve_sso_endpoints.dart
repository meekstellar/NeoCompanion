import 'package:dio/dio.dart';
import 'package:jose/jose.dart';

class EveSsoMetadata {
  const EveSsoMetadata({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.revocationEndpoint,
    required this.jwksUri,
  });

  final String issuer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String revocationEndpoint;
  final String jwksUri;
}

class EveSsoEndpoints {
  EveSsoEndpoints({
    Dio? dio,
    String discoveryUrl =
        'https://login.eveonline.com/.well-known/oauth-authorization-server',
    Duration jwksTtl = const Duration(hours: 24),
  })  : _dio = dio ?? Dio(),
        _discoveryUrl = discoveryUrl,
        _jwksTtl = jwksTtl;

  final Dio _dio;
  final String _discoveryUrl;
  final Duration _jwksTtl;

  EveSsoMetadata? _metadata;
  JsonWebKeyStore? _keyStore;
  DateTime? _keyStoreFetchedAt;

  Future<EveSsoMetadata> metadata() async {
    final cached = _metadata;
    if (cached != null) return cached;
    final res = await _dio.getUri<Map<String, dynamic>>(Uri.parse(_discoveryUrl));
    final data = res.data!;
    final meta = EveSsoMetadata(
      issuer: data['issuer'] as String,
      authorizationEndpoint: data['authorization_endpoint'] as String,
      tokenEndpoint: data['token_endpoint'] as String,
      revocationEndpoint: data['revocation_endpoint'] as String,
      jwksUri: data['jwks_uri'] as String,
    );
    _metadata = meta;
    return meta;
  }

  Future<JsonWebKeyStore> keyStore() async {
    final cached = _keyStore;
    final fetchedAt = _keyStoreFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _jwksTtl) {
      return cached;
    }
    final meta = await metadata();
    final res = await _dio.getUri<Map<String, dynamic>>(Uri.parse(meta.jwksUri));
    final store = JsonWebKeyStore()..addKeySet(JsonWebKeySet.fromJson(res.data!));
    _keyStore = store;
    _keyStoreFetchedAt = DateTime.now();
    return store;
  }
}
