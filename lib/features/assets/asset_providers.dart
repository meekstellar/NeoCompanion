import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'asset_node.dart';
import 'data/asset_repository.dart';
import 'data/dto/asset_item.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(ref.watch(esiClientProvider));
});

/// IDs at or above this value are player-anchored structures (citadels)
/// resolved via `/universe/structures/{id}/`. Anything below is NPC
/// stations / characters / corps / alliances and resolves via
/// `/universe/names/`.
const int _structureIdThreshold = 100000000;

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
  final character = ref.watch(characterRepositoryProvider);
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

  // Outer locations are the keys of the tree — each one is a station,
  // system, or structure (any non-asset location id). We need names for
  // those that the local SDE doesn't already know about (NPC stations
  // and systems both resolve locally; only player structures and other
  // non-SDE ids fall through to ESI).
  final unresolved = <int>{
    for (final id in tree.rootsByLocation.keys)
      if (typesDb.lookupSystem(id) == null && typesDb.lookupStation(id) == null)
        id,
  };

  // ESI splits naming into two endpoints. NPC stations / characters /
  // corps / alliances all live below ~100M and resolve via the public
  // `/universe/names/` POST. Player-anchored structures (citadels) sit
  // far above that range and need authorized per-id `/universe/structures/`
  // calls; foreign citadels we can't dock at come back as 403 and stay
  // unresolved.
  final nameableIds = <int>[];
  final structureIds = <int>[];
  for (final id in unresolved) {
    if (id >= _structureIdThreshold) {
      structureIds.add(id);
    } else {
      nameableIds.add(id);
    }
  }

  final esiNames = <int, String>{};
  await Future.wait<void>([
    if (nameableIds.isNotEmpty)
      character.resolveNames(nameableIds).then((resolved) {
        for (final n in resolved) {
          esiNames[n.id] = n.name;
        }
      }).catchError((_) {/* keep partial results */}),
    if (structureIds.isNotEmpty)
      character.fetchStructures(characterId, structureIds).then((resolved) {
        for (final entry in resolved.entries) {
          esiNames[entry.key] = entry.value.name;
        }
      }).catchError((_) {/* keep partial results */}),
  ]);

  // Direct display name per locationId — no combined "Container — Outer"
  // strings; the screen renders the hierarchy itself.
  String? nameOf(int id) {
    // Player-assigned name on a container/ship wins over its type name.
    final custom = customNames[id];
    if (custom != null) return custom;
    final system = typesDb.lookupSystem(id);
    if (system != null) return system;
    final station = typesDb.lookupStation(id);
    if (station != null) return station;
    final esi = esiNames[id];
    if (esi != null) return esi;
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
