import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'data/clones_repository.dart';
import 'data/dto/clones_data.dart';

final clonesRepositoryProvider = Provider<ClonesRepository>((ref) {
  return ClonesRepository(ref.watch(esiClientProvider));
});

class ClonesView {
  const ClonesView({
    required this.data,
    required this.locationNames,
  });

  final ClonesData data;
  final Map<int, String> locationNames;
}

final jumpClonesProvider =
    FutureProvider.family<ClonesView, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(clonesRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final data = await repo.fetch(characterId);

  // Local-first location resolution: solar systems via SDE, the rest
  // through /universe/names/.
  final locationNames = <int, String>{};
  final unresolved = <int>{};
  final allLocationIds = <int>{
    if (data.homeLocation != null) data.homeLocation!.locationId,
    for (final c in data.jumpClones) c.location.locationId,
  };
  for (final id in allLocationIds) {
    final system = typesDb.lookupSystem(id);
    if (system != null) {
      locationNames[id] = system;
    } else {
      unresolved.add(id);
    }
  }
  if (unresolved.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(unresolved.toList());
      for (final n in resolved) {
        locationNames[n.id] = n.name;
      }
    } catch (_) {
      // Player structures stay as Unknown.
    }
  }

  return ClonesView(data: data, locationNames: locationNames);
});
