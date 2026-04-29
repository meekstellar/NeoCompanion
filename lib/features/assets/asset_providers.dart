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

  // Type names: local SDE only.
  final typeNames = <int, String>{};
  for (final item in items) {
    final name = typesDb.lookup(item.typeId);
    if (name != null) typeNames[item.typeId] = name;
  }

  // Location resolution prefers local lookups (solar systems) and
  // containers we already own; only the rest goes to /universe/names/.
  final locationNames = <int, String>{};
  final itemIdToType = {for (final i in items) i.itemId: i.typeId};
  final unresolved = <int>[];
  final locationIds = <int>{for (final i in items) i.locationId};
  for (final id in locationIds) {
    final system = typesDb.lookupSystem(id);
    if (system != null) {
      locationNames[id] = system;
      continue;
    }
    final containerType = itemIdToType[id];
    if (containerType != null) {
      final containerName = typesDb.lookup(containerType);
      if (containerName != null) {
        locationNames[id] = '$containerName (container)';
        continue;
      }
    }
    unresolved.add(id);
  }
  if (unresolved.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(unresolved);
      for (final n in resolved) {
        locationNames[n.id] = n.name;
      }
    } catch (_) {
      // Player structures stay as raw IDs.
    }
  }

  return AssetsData(
    items: items,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
