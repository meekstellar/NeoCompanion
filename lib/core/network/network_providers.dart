import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'esi_client.dart';

final esiClientProvider = Provider<EsiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return EsiClient(
    tokens: ref.watch(tokenManagerProvider),
    compatibilityDate: config.esiCompatibilityDate,
  );
});
