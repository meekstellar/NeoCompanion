import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'data/dto/market_order.dart';
import 'data/market_repository.dart';

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.watch(esiClientProvider));
});

class MarketOrdersData {
  const MarketOrdersData({
    required this.orders,
    required this.typeNames,
    required this.locationNames,
  });

  final List<MarketOrder> orders;
  final Map<int, String> typeNames;
  final Map<int, String> locationNames;
}

final marketOrdersProvider =
    FutureProvider.family<MarketOrdersData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final market = ref.watch(marketRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final orders = await market.fetchOpenOrders(characterId);

  final typeNames = <int, String>{};
  for (final o in orders) {
    final n = typesDb.lookup(o.typeId);
    if (n != null) typeNames[o.typeId] = n;
  }

  // Most order locations are stations or structures, but a few are
  // solar systems (citadels in space). Resolve those locally first;
  // anything left over goes to /universe/names/.
  final locationIds = {for (final o in orders) o.locationId}.toList();
  final locationNames = <int, String>{};
  final unresolved = <int>[];
  for (final id in locationIds) {
    final local = typesDb.lookupSystem(id);
    if (local != null) {
      locationNames[id] = local;
    } else {
      unresolved.add(id);
    }
  }
  if (unresolved.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(unresolved);
      for (final n in resolved) {
        locationNames[n.id] = n.name;
      }
    } catch (_) {
      // Player structures keep their raw ID.
    }
  }

  return MarketOrdersData(
    orders: orders,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
