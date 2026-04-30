import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/dto/planet_layout.dart';
import 'data/dto/planet_summary.dart';
import 'data/planet_repository.dart';

final planetRepositoryProvider = Provider<PlanetRepository>((ref) {
  return PlanetRepository(ref.watch(esiClientProvider));
});

class PlanetColoniesData {
  const PlanetColoniesData({
    required this.colonies,
    required this.systemNames,
  });

  final List<PlanetSummary> colonies;
  final Map<int, String> systemNames;
}

final planetColoniesProvider =
    FutureProvider.family<PlanetColoniesData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(planetRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final colonies = await repo.fetchColonies(characterId);
  // Solar system names live entirely in the SDE — no ESI round-trip.
  final systemNames = <int, String>{
    for (final c in colonies)
      if (typesDb.lookupSystem(c.solarSystemId) != null)
        c.solarSystemId: typesDb.lookupSystem(c.solarSystemId)!,
  };
  return PlanetColoniesData(colonies: colonies, systemNames: systemNames);
});

class PlanetLayoutKey {
  const PlanetLayoutKey({required this.characterId, required this.planetId});
  final int characterId;
  final int planetId;

  @override
  bool operator ==(Object other) =>
      other is PlanetLayoutKey &&
      other.characterId == characterId &&
      other.planetId == planetId;

  @override
  int get hashCode => Object.hash(characterId, planetId);
}

final planetLayoutProvider =
    FutureProvider.family<PlanetLayout, PlanetLayoutKey>((ref, key) {
  final repo = ref.watch(planetRepositoryProvider);
  return repo.fetchLayout(key.characterId, key.planetId);
});
