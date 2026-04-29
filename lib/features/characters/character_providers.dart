import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import 'data/character_repository.dart';
import 'data/dto/character_location.dart';
import 'data/dto/character_portrait.dart';
import 'data/dto/character_public_info.dart';
import 'data/dto/character_ship.dart';
import 'data/dto/universe_name.dart';

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
  final repo = ref.watch(characterRepositoryProvider);

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

  // Player-owned structures need the dedicated /universe/structures/{id}/
  // endpoint (auth required); skip them in MVP and resolve only the IDs
  // that /universe/names/ can answer for.
  final ids = <int>{
    publicInfo.corporationId,
    if (publicInfo.allianceId != null) publicInfo.allianceId!,
    location.solarSystemId,
    if (location.stationId != null) location.stationId!,
    ship.shipTypeId,
  }.toList();

  List<UniverseName> names = const [];
  try {
    names = await repo.resolveNames(ids);
  } catch (_) {
    // Name resolution is non-essential — render IDs if it fails.
  }
  final resolved = {for (final n in names) n.id: n.name};

  return CharacterSheetData(
    publicInfo: publicInfo,
    portrait: portrait,
    location: location,
    ship: ship,
    walletBalance: walletBalance,
    resolvedNames: resolved,
  );
});
