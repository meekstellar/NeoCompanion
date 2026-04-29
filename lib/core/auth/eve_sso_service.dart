import 'package:flutter_appauth/flutter_appauth.dart';

import 'authenticated_character.dart';
import 'eve_sso_endpoints.dart';
import 'jwt_validator.dart';
import 'sso_scopes.dart';
import 'token_manager.dart';
import 'token_set.dart';

class SsoSignInException implements Exception {
  SsoSignInException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'SsoSignInException: $message${cause == null ? '' : ' ($cause)'}';
}

class EveSsoService {
  EveSsoService({
    required FlutterAppAuth appAuth,
    required EveSsoEndpoints endpoints,
    required JwtValidator validator,
    required TokenManager tokens,
    required String clientId,
    required String callbackScheme,
  })  : _appAuth = appAuth,
        _endpoints = endpoints,
        _validator = validator,
        _tokens = tokens,
        _clientId = clientId,
        _callbackScheme = callbackScheme;

  final FlutterAppAuth _appAuth;
  final EveSsoEndpoints _endpoints;
  final JwtValidator _validator;
  final TokenManager _tokens;
  final String _clientId;
  final String _callbackScheme;

  String get _redirectUrl => '$_callbackScheme://callback';

  Future<AuthenticatedCharacter> signIn({
    List<String> scopes = eveMvpScopes,
  }) async {
    final meta = await _endpoints.metadata();
    final AuthorizationTokenResponse result;
    try {
      result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: meta.authorizationEndpoint,
            tokenEndpoint: meta.tokenEndpoint,
          ),
          scopes: scopes,
          allowInsecureConnections: false,
        ),
      );
    } catch (e) {
      throw SsoSignInException('Authorization flow failed', e);
    }

    final accessToken = result.accessToken;
    final refreshToken = result.refreshToken;
    if (accessToken == null || refreshToken == null) {
      throw SsoSignInException('SSO returned no tokens');
    }

    final claims = await _validator.validate(accessToken);
    final expiresAt = result.accessTokenExpirationDateTime ?? claims.expiresAt;

    final tokenSet = TokenSet(
      characterId: claims.characterId,
      characterName: claims.characterName,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      scopes: claims.scopes,
    );
    await _tokens.store(tokenSet);

    return AuthenticatedCharacter(
      id: claims.characterId,
      name: claims.characterName,
      scopes: claims.scopes,
    );
  }
}
