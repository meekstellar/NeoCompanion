import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/character_repository.dart';
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

  // Resolve everything we can from the local SDE before going to the
  // network. Solar systems and inventory types live there; faction
  // names too, when ESI returns one.
  void tryLocal(int? id, String? Function(int) lookup) {
    if (id == null) return;
    final name = lookup(id);
    if (name != null) resolved[id] = name;
  }

  tryLocal(location.solarSystemId, typesDb.lookupSystem);
  tryLocal(ship.shipTypeId, typesDb.lookup);
  tryLocal(publicInfo.factionId, typesDb.lookupFaction);
  tryLocal(publicInfo.corporationId, typesDb.lookupNpcCorporation);

  // Player-owned structures need the dedicated /universe/structures/{id}/
  // endpoint (auth required); skip them in MVP and resolve only the IDs
  // that /universe/names/ can answer for.
  final remaining = <int>{
    publicInfo.corporationId,
    if (publicInfo.allianceId != null) publicInfo.allianceId!,
    if (location.stationId != null) location.stationId!,
  }.where((id) => !resolved.containsKey(id)).toList();

  if (remaining.isNotEmpty) {
    try {
      final names = await repo.resolveNames(remaining);
      for (final n in names) {
        resolved[n.id] = n.name;
      }
    } catch (_) {
      // Name resolution is non-essential — render IDs if it fails.
    }
  }

  return CharacterSheetData(
    publicInfo: publicInfo,
    portrait: portrait,
    location: location,
    ship: ship,
    walletBalance: walletBalance,
    resolvedNames: resolved,
  );
});
