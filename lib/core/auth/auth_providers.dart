import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../storage/secure_key_value_store.dart';
import 'eve_sso_endpoints.dart';
import 'eve_sso_service.dart';
import 'jwt_validator.dart';
import 'token_manager.dart';
import 'token_set.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in ProviderScope');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore(ref.watch(secureStorageProvider));
});

final dioProvider = Provider<Dio>((ref) => Dio());

final appAuthProvider = Provider<FlutterAppAuth>((ref) => const FlutterAppAuth());

final eveSsoEndpointsProvider = Provider<EveSsoEndpoints>((ref) {
  return EveSsoEndpoints(dio: ref.watch(dioProvider));
});

final jwtValidatorProvider = Provider<JwtValidator>((ref) {
  return JwtValidator(endpoints: ref.watch(eveSsoEndpointsProvider));
});

final tokenManagerProvider = Provider<TokenManager>((ref) {
  return TokenManager(
    storage: ref.watch(secureKeyValueStoreProvider),
    endpoints: ref.watch(eveSsoEndpointsProvider),
    clientId: ref.watch(appConfigProvider).eveClientId,
    dio: ref.watch(dioProvider),
  );
});

final eveSsoServiceProvider = Provider<EveSsoService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return EveSsoService(
    appAuth: ref.watch(appAuthProvider),
    endpoints: ref.watch(eveSsoEndpointsProvider),
    validator: ref.watch(jwtValidatorProvider),
    tokens: ref.watch(tokenManagerProvider),
    clientId: cfg.eveClientId,
    callbackScheme: cfg.eveCallbackScheme,
  );
});

class ActiveCharacterId extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final activeCharacterIdProvider =
    NotifierProvider<ActiveCharacterId, int?>(ActiveCharacterId.new);

final storedCharactersProvider = FutureProvider<List<TokenSet>>((ref) async {
  final tm = ref.watch(tokenManagerProvider);
  final ids = await tm.listCharacterIds();
  final list = <TokenSet>[];
  for (final id in ids) {
    final t = await tm.read(id);
    if (t != null) list.add(t);
  }
  return list;
});
