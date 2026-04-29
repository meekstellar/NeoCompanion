import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/character_providers.dart';
import '../auth/auth_providers.dart';
import '../network/network_providers.dart';
import 'types_database.dart';
import 'types_database_checker.dart';
import 'types_database_updater.dart';

final typesDatabaseProvider = Provider<TypesDatabase>((ref) {
  throw UnimplementedError(
    'typesDatabaseProvider must be overridden in ProviderScope',
  );
});

final typesDatabaseUpdaterProvider = Provider<TypesDatabaseUpdater>((ref) {
  return TypesDatabaseUpdater(
    esi: ref.watch(esiClientProvider),
    character: ref.watch(characterRepositoryProvider),
    database: ref.watch(typesDatabaseProvider),
  );
});

/// Bumps every time the database is committed. Feature providers that
/// derive state from type names should `ref.watch` this so they rebuild
/// whenever the user finishes an update.
class TypesDatabaseRevision extends Notifier<int> {
  @override
  int build() {
    final db = ref.watch(typesDatabaseProvider);
    void listener() => state = state + 1;
    db.addListener(listener);
    ref.onDispose(() => db.removeListener(listener));
    return 0;
  }
}

final typesDatabaseRevisionProvider =
    NotifierProvider<TypesDatabaseRevision, int>(TypesDatabaseRevision.new);

final typesDatabaseCheckerProvider = Provider<TypesDatabaseChecker>((ref) {
  return TypesDatabaseChecker(
    database: ref.watch(typesDatabaseProvider),
    compatibilityDate: ref.watch(appConfigProvider).esiCompatibilityDate,
  );
});

/// Asks CCP whether the local DB matches their first page of types.
/// `true` = fresh, `false` = update available, `null` while in flight or
/// when the probe failed (banner stays hidden on errors).
final typesDatabaseFreshnessProvider = FutureProvider<bool?>((ref) async {
  ref.watch(typesDatabaseRevisionProvider);
  final db = ref.watch(typesDatabaseProvider);
  if (!db.isReady) return false;
  try {
    return await ref.watch(typesDatabaseCheckerProvider).isFresh();
  } catch (_) {
    return null;
  }
});
