import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../characters/character_providers.dart';
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
  final repo = ref.watch(fittingRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final fittings = await repo.fetchAll(characterId);

  final ids = <int>{
    for (final f in fittings) ...[
      f.shipTypeId,
      for (final i in f.items) i.typeId,
    ],
  }.toList();

  var names = <int, String>{};
  if (ids.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(ids);
      names = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Render IDs if name resolution fails.
    }
  }

  return FittingsData(fittings: fittings, typeNames: names);
});
