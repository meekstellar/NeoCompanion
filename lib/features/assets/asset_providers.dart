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
    required this.outerLocation,
  });

  final List<AssetItem> items;
  final Map<int, String> typeNames;

  /// Direct display name for a `locationId`: solar system, ESI-resolved
  /// station/structure, or just the container's type name (e.g.
  /// "Epithal"). For unknown locations the entry is missing.
  final Map<int, String> locationNames;

  /// For each `locationId` seen on an item, the outermost station /
  /// system / structure id that contains it (after walking through any
  /// of our own containers). Used to deduplicate "Epithal in Jita" and
  /// "Epithal in Jita" into one Jita group.
  final Map<int, int> outerLocation;
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

  final itemIdToType = {for (final i in items) i.itemId: i.typeId};
  final itemIdToLocation = {for (final i in items) i.itemId: i.locationId};

  // Walk container chain → find the outermost location for any id.
  int outerOf(int id) {
    var current = id;
    final visited = <int>{};
    while (visited.add(current)) {
      final outerId = itemIdToType.containsKey(current)
          ? itemIdToLocation[current]
          : null;
      if (outerId == null) break;
      current = outerId;
    }
    return current;
  }

  final outerLocation = <int, int>{};
  for (final i in items) {
    outerLocation.putIfAbsent(i.locationId, () => outerOf(i.locationId));
  }

  // Ask ESI for names of outermost locations we couldn't resolve locally.
  final unresolved = <int>{};
  for (final outerId in outerLocation.values) {
    if (typesDb.lookupSystem(outerId) != null) continue;
    if (itemIdToType.containsKey(outerId)) continue; // self-contained chain
    unresolved.add(outerId);
  }

  Map<int, String> esiNames = const {};
  if (unresolved.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(unresolved.toList());
      esiNames = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Player structures stay Unknown.
    }
  }

  // Direct display name per locationId — no combined "Container — Outer"
  // strings; the screen renders the hierarchy itself.
  String? nameOf(int id) {
    final system = typesDb.lookupSystem(id);
    if (system != null) return system;
    final esi = esiNames[id];
    if (esi != null) return esi;
    final ctype = itemIdToType[id];
    if (ctype != null) return typesDb.lookup(ctype);
    return null;
  }

  final locationNames = <int, String>{};
  final allIds = <int>{
    ...outerLocation.keys,
    ...outerLocation.values,
  };
  for (final id in allIds) {
    final name = nameOf(id);
    if (name != null) locationNames[id] = name;
  }

  return AssetsData(
    items: items,
    typeNames: typeNames,
    locationNames: locationNames,
    outerLocation: outerLocation,
  );
});
