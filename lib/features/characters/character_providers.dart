import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/character_repository.dart';
import 'data/dto/character_attributes.dart';
import 'data/dto/character_location.dart';
import 'data/dto/character_portrait.dart';
import 'data/dto/character_public_info.dart';
import 'data/dto/character_ship.dart';

final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  return CharacterRepository(ref.watch(esiClientProvider));
});

class CharacterSheetData {
  const CharacterSheetData({
    required this.publicInfo,
    required this.portrait,
    required this.location,
    required this.ship,
    required this.walletBalance,
    required this.resolvedNames,
  });

  final CharacterPublicInfo publicInfo;
  final CharacterPortrait portrait;
  final CharacterLocation location;
  final CharacterShip ship;
  final double walletBalance;
  final Map<int, String> resolvedNames;

  String? nameOf(int? id) => id == null ? null : resolvedNames[id];
}

final characterSheetProvider =
    FutureProvider.family<CharacterSheetData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(characterRepositoryProvider);
  final resolver = ref.watch(locationResolverProvider(characterId));
  final typesDb = ref.watch(typesDatabaseProvider);

  final results = await Future.wait([
    repo.fetchPublic(characterId),
    repo.fetchPortrait(characterId),
    repo.fetchLocation(characterId),
    repo.fetchShip(characterId),
    repo.fetchWalletBalance(characterId),
  ]);

  final publicInfo = results[0] as CharacterPublicInfo;
  final portrait = results[1] as CharacterPortrait;
  final location = results[2] as CharacterLocation;
  final ship = results[3] as CharacterShip;
  final walletBalance = results[4] as double;

  final resolved = <int, String>{};

  // Things only the SDE can name (factions, NPC corps, inventory
  // types) — the location resolver doesn't know about these.
  void tryLocal(int? id, String? Function(int) lookup) {
    if (id == null) return;
    final name = lookup(id);
    if (name != null) resolved[id] = name;
  }

  tryLocal(ship.shipTypeId, typesDb.lookup);
  tryLocal(publicInfo.factionId, typesDb.lookupFaction);
  tryLocal(publicInfo.corporationId, typesDb.lookupNpcCorporation);

  // Anything that could be a station, citadel, or system goes through
  // the shared resolver: local SDE first (system, NPC station), then
  // /universe/names/ for ids < 100M and /universe/structures/{id}/ for
  // citadels (≥ 100M).
  final toResolve = <int>{
    location.solarSystemId,
    if (location.stationId != null) location.stationId!,
    if (location.structureId != null) location.structureId!,
    publicInfo.corporationId,
    if (publicInfo.allianceId != null) publicInfo.allianceId!,
  }..removeAll(resolved.keys);

  resolved.addAll(await resolver.resolve(toResolve));

  return CharacterSheetData(
    publicInfo: publicInfo,
    portrait: portrait,
    location: location,
    ship: ship,
    walletBalance: walletBalance,
    resolvedNames: resolved,
  );
});

final characterAttributesProvider =
    FutureProvider.family<CharacterAttributes, int>((ref, characterId) {
  return ref.watch(characterRepositoryProvider).fetchAttributes(characterId);
});

final characterImplantsProvider =
    FutureProvider.family<List<int>, int>((ref, characterId) {
  return ref.watch(characterRepositoryProvider).fetchImplants(characterId);
});
