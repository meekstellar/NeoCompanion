import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'types_database.dart';
import 'types_database_checker.dart';
import 'types_database_updater.dart';

final typesDatabaseProvider = Provider<TypesDatabase>((ref) {
  throw UnimplementedError(
    'typesDatabaseProvider must be overridden in ProviderScope',
  );
});

/// Bare Dio used by the SDE pipeline. Distinct from [esiClientProvider]
/// because the SDE archive lives on developers.eveonline.com (not ESI)
/// and shouldn't carry any auth interceptors.
final sdeDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    headers: {'User-Agent': 'NeoCompanion (SDE pipeline)'},
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(minutes: 1),
  ));
});

final typesDatabaseUpdaterProvider = Provider<TypesDatabaseUpdater>((ref) {
  return TypesDatabaseUpdater(
    dio: ref.watch(sdeDioProvider),
    database: ref.watch(typesDatabaseProvider),
  );
});

/// Bumps every time the database is swapped. Feature providers that
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
    dio: ref.watch(sdeDioProvider),
  );
});

/// Asks CCP whether the local SDE build matches the latest published
/// one. `true` = fresh, `false` = update available, `null` while in
/// flight or when the probe failed.
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
