import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'data/asset_repository.dart';
import 'data/dto/asset_item.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(ref.watch(esiClientProvider));
});

class AssetsData {
  const AssetsData({
    required this.items,
    required this.typeNames,
    required this.locationNames,
  });

  final List<AssetItem> items;
  final Map<int, String> typeNames;
  final Map<int, String> locationNames;
}

final assetsProvider =
    FutureProvider.family<AssetsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(assetRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final items = await repo.fetchAll(characterId);

  // Type names come from the local DB; nothing fetched per-screen.
  final typeNames = <int, String>{};
  for (final item in items) {
    final name = typesDb.lookup(item.typeId);
    if (name != null) typeNames[item.typeId] = name;
  }

  // Locations still go through /universe/names/ (small set, includes
  // stations and solar systems). Player structures simply stay missing.
  final locationIds = {for (final i in items) i.locationId}.toList();
  var locationNames = <int, String>{};
  if (locationIds.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(locationIds);
      locationNames = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Render raw IDs.
    }
  }

  // Locations that are themselves an item we own (containers, ships).
  for (final item in items) {
    if (locationNames.containsKey(item.locationId)) continue;
    final containerType = items
        .where((i) => i.itemId == item.locationId)
        .map((i) => i.typeId)
        .firstOrNull;
    if (containerType != null) {
      final containerName = typesDb.lookup(containerType);
      if (containerName != null) {
        locationNames[item.locationId] = '$containerName (container)';
      }
    }
  }

  return AssetsData(
    items: items,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
