import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqflite.dart';

import 'data/dto/local_fitting.dart';
import 'data/local_fitting_repository.dart';

/// Holds the writable app database. Overridden in `bootstrap`. The
/// fittings repo is the only consumer for now; future local features
/// (watchlists, custom skill plans, …) plug into the same handle.
final appDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden in ProviderScope',
  );
});

final localFittingRepositoryProvider = Provider<LocalFittingRepository>((ref) {
  return LocalFittingRepository(ref.watch(appDatabaseProvider));
});

/// Bumps every time a local fitting is created/updated/deleted so the
/// list and detail screens can re-fetch.
class LocalFittingsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final localFittingsRevisionProvider =
    NotifierProvider<LocalFittingsRevision, int>(LocalFittingsRevision.new);

final localFittingsListProvider =
    FutureProvider<List<LocalFitting>>((ref) async {
  ref.watch(localFittingsRevisionProvider);
  return ref.watch(localFittingRepositoryProvider).listAll();
});

final localFittingProvider =
    FutureProvider.family<LocalFitting?, int>((ref, id) async {
  ref.watch(localFittingsRevisionProvider);
  return ref.watch(localFittingRepositoryProvider).get(id);
});
