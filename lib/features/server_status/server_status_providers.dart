import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import 'data/dto/server_status.dart';
import 'data/server_status_repository.dart';

final serverStatusRepositoryProvider =
    Provider<ServerStatusRepository>((ref) {
  return ServerStatusRepository(ref.watch(esiClientProvider));
});

/// Latest cluster status. ESI caches the endpoint ~30s server-side;
/// our cache interceptor honours that. Failures (network down) come
/// out as an error state so the UI can dim the indicator gracefully.
final serverStatusProvider = FutureProvider<ServerStatus>((ref) async {
  final repo = ref.watch(serverStatusRepositoryProvider);
  return repo.fetchStatus();
});
