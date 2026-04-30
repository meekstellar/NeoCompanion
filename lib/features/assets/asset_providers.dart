import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'asset_node.dart';
import 'data/asset_repository.dart';
import 'data/dto/asset_item.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(ref.watch(esiClientProvider));
});

class AssetsData {
  const AssetsData({
    required this.items,
    required this.tree,
    required this.typeNames,
    required this.customNames,
    required this.itemIdToType,
    required this.locationNames,
  });

  final List<AssetItem> items;

  /// Recursive container hierarchy: each top-level location holds a
  /// list of nodes, each of which can have further children. See
  /// [AssetNode] / [buildAssetTree].
  final AssetTree tree;

  final Map<int, String> typeNames;

  /// Player-assigned names for singleton items (ships, containers, …),
  /// keyed by `itemId`. Items the player hasn't renamed are absent.
  final Map<int, String> customNames;

  /// `itemId → typeId` for every fetched asset. Lets the UI find the
  /// type of a container without scanning the items list.
  final Map<int, int> itemIdToType;

  /// Direct display name for a `locationId`: solar system, ESI-resolved
  /// station/structure, or just the container's type name (e.g.
  /// "Epithal"). For unknown locations the entry is missing.
  final Map<int, String> locationNames;
}

final assetsProvider =
    FutureProvider.family<AssetsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(assetRepositoryProvider);
  final resolver = ref.watch(locationResolverProvider(characterId));
  final typesDb = ref.watch(typesDatabaseProvider);

  final items = await repo.fetchAll(characterId);

  // Type names from local SDE.
  final typeNames = <int, String>{};
  for (final i in items) {
    final n = typesDb.lookup(i.typeId);
    if (n != null) typeNames[i.typeId] = n;
  }

  // Player-set names. ESI requires `is_singleton: true` ids; non-singletons
  // (stacks of charges etc.) can't carry names anyway. Failures are
  // swallowed inside the repo per-chunk.
  final singletonIds = [
    for (final i in items)
      if (i.isSingleton) i.itemId,
  ];
  final customNames = await repo.fetchNames(characterId, singletonIds);

  final itemIdToType = {for (final i in items) i.itemId: i.typeId};
  final tree = buildAssetTree(items);

  // Resolve outer locations (stations / systems / citadels) in one shot.
  final resolvedLocations =
      await resolver.resolve(tree.rootsByLocation.keys);

  // Direct display name per locationId — no combined "Container — Outer"
  // strings; the screen renders the hierarchy itself.
  String? nameOf(int id) {
    // Player-assigned name on a container/ship wins over its type name.
    final custom = customNames[id];
    if (custom != null) return custom;
    final fromResolver = resolvedLocations[id];
    if (fromResolver != null) return fromResolver;
    final ctype = itemIdToType[id];
    if (ctype != null) return typesDb.lookup(ctype);
    return null;
  }

  // Resolve display names for every id we'll plausibly need to render:
  // outer locations (station/system/structure) and every container
  // itemId (ship, can, …) so the UI can show "My Hauler" instead of
  // "Epithal" when a player named it.
  final locationNames = <int, String>{};
  final allIds = <int>{
    ...tree.rootsByLocation.keys,
    ...itemIdToType.keys,
  };
  for (final id in allIds) {
    final name = nameOf(id);
    if (name != null) locationNames[id] = name;
  }

  return AssetsData(
    items: items,
    tree: tree,
    typeNames: typeNames,
    customNames: customNames,
    itemIdToType: itemIdToType,
    locationNames: locationNames,
  );
});
