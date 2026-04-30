import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
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
  final resolver = ref.watch(locationResolverProvider(characterId));
  final typesDb = ref.watch(typesDatabaseProvider);

  final orders = await market.fetchOpenOrders(characterId);

  final typeNames = <int, String>{};
  for (final o in orders) {
    final n = typesDb.lookup(o.typeId);
    if (n != null) typeNames[o.typeId] = n;
  }

  final locationNames =
      await resolver.resolve({for (final o in orders) o.locationId});

  return MarketOrdersData(
    orders: orders,
    typeNames: typeNames,
    locationNames: locationNames,
  );
});
