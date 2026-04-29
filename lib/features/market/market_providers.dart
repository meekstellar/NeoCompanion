import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
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
  final market = ref.watch(marketRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final orders = await market.fetchOpenOrders(characterId);

  final ids = <int>{
    for (final o in orders) ...[o.typeId, o.locationId],
  }.toList();

  var resolved = <int, String>{};
  if (ids.isNotEmpty) {
    try {
      final names = await character.resolveNames(ids);
      resolved = {for (final n in names) n.id: n.name};
    } catch (_) {
      // Player structures don't resolve via /universe/names/; keep the ID.
    }
  }

  final typeNames = <int, String>{};
  final locationNames = <int, String>{};
  for (final o in orders) {
    final t = resolved[o.typeId];
    if (t != null) typeNames[o.typeId] = t;
    final l = resolved[o.locationId];
    if (l != null) locationNames[o.locationId] = l;
  }

  return MarketOrdersData(
    orders: orders,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
