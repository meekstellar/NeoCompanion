import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// Streams `true` while the device has *any* network interface up. We don't
/// distinguish wifi/mobile here — ESI just needs an internet route.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final c = ref.watch(_connectivityProvider);
  final initial = await c.checkConnectivity();
  yield _isOnline(initial);
  yield* c.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) {
  return results.any((r) => r != ConnectivityResult.none);
}
