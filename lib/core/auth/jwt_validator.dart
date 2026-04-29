import 'package:jose/jose.dart';

import 'eve_sso_endpoints.dart';

class JwtValidationException implements Exception {
  JwtValidationException(this.message);
  final String message;
  @override
  String toString() => 'JwtValidationException: $message';
}

class EveJwtClaims {
  const EveJwtClaims({
    required this.characterId,
    required this.characterName,
    required this.scopes,
    required this.expiresAt,
  });

  final int characterId;
  final String characterName;
  final List<String> scopes;
  final DateTime expiresAt;
}

class JwtValidator {
  JwtValidator({
    required EveSsoEndpoints endpoints,
    String expectedAudience = 'EVE Online',
  })  : _endpoints = endpoints,
        _expectedAudience = expectedAudience;

  final EveSsoEndpoints _endpoints;
  final String _expectedAudience;

  Future<EveJwtClaims> validate(String accessToken) async {
    final jws = JsonWebSignature.fromCompactSerialization(accessToken);
    final keyStore = await _endpoints.keyStore();
    final verified = await jws.getPayload(keyStore);
    final claims = JsonWebTokenClaims.fromJson(verified.jsonContent);

    final meta = await _endpoints.metadata();
    if (claims.issuer?.toString() != meta.issuer) {
      throw JwtValidationException('issuer mismatch: ${claims.issuer}');
    }

    final audiences = claims.audience ?? const [];
    if (!audiences.contains(_expectedAudience)) {
      throw JwtValidationException('audience missing $_expectedAudience');
    }

    final exp = claims.expiry;
    if (exp == null || DateTime.now().isAfter(exp)) {
      throw JwtValidationException('token expired');
    }

    final sub = claims.subject;
    if (sub == null || !sub.startsWith('CHARACTER:EVE:')) {
      throw JwtValidationException('unexpected subject: $sub');
    }
    final characterId = int.parse(sub.substring('CHARACTER:EVE:'.length));

    final rawScopes = claims['scp'];
    final scopes = switch (rawScopes) {
      String s => s.split(' '),
      List l => l.cast<String>(),
      _ => <String>[],
    };

    return EveJwtClaims(
      characterId: characterId,
      characterName: claims['name'] as String? ?? '',
      scopes: scopes,
      expiresAt: exp,
    );
  }
}
