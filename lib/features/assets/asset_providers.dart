import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
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
  final assets = ref.watch(assetRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final items = await assets.fetchAll(characterId);

  final typeIds = {for (final i in items) i.typeId}.toList();
  final locationIds = {for (final i in items) i.locationId}.toList();

  final allIds = <int>{...typeIds, ...locationIds}.toList();
  var resolved = <int, String>{};
  if (allIds.isNotEmpty) {
    try {
      final names = await character.resolveNames(allIds);
      resolved = {for (final n in names) n.id: n.name};
    } catch (_) {
      // /universe/names/ refuses unknown id types (e.g. structures).
      // Render raw IDs in those cases.
    }
  }

  final typeNames = <int, String>{};
  for (final id in typeIds) {
    final name = resolved[id];
    if (name != null) typeNames[id] = name;
  }

  // Locations that are themselves another asset (containers / ships).
  final itemIdToType = {for (final i in items) i.itemId: i.typeId};
  final locationNames = <int, String>{};
  for (final id in locationIds) {
    final direct = resolved[id];
    if (direct != null) {
      locationNames[id] = direct;
      continue;
    }
    final containerType = itemIdToType[id];
    if (containerType != null) {
      final containerName = resolved[containerType];
      if (containerName != null) {
        locationNames[id] = '$containerName (container)';
      }
    }
  }

  return AssetsData(
    items: items,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
