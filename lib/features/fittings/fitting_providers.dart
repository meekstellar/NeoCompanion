import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/dto/fitting.dart';
import 'data/fitting_repository.dart';

final fittingRepositoryProvider = Provider<FittingRepository>((ref) {
  return FittingRepository(ref.watch(esiClientProvider));
});

class FittingsData {
  const FittingsData({required this.fittings, required this.typeNames});

  final List<Fitting> fittings;
  final Map<int, String> typeNames;
}

final fittingsProvider =
    FutureProvider.family<FittingsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(fittingRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final fittings = await repo.fetchAll(characterId);

  final names = <int, String>{};
  for (final f in fittings) {
    final ship = typesDb.lookup(f.shipTypeId);
    if (ship != null) names[f.shipTypeId] = ship;
    for (final i in f.items) {
      final n = typesDb.lookup(i.typeId);
      if (n != null) names[i.typeId] = n;
    }
  }

  return FittingsData(fittings: fittings, typeNames: names);
});
