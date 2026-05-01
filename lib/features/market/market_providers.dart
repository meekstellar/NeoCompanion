import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/dto/market_history_entry.dart';
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

/// Daily price/volume history for one type, defaulting to The Forge.
/// Family key encodes both `typeId` and `regionId` so multiple regions
/// could be requested side-by-side later (we don't expose region
/// switching in the UI yet, but the provider is ready for it).
class MarketHistoryKey {
  const MarketHistoryKey({required this.typeId, required this.regionId});
  final int typeId;
  final int regionId;

  @override
  bool operator ==(Object other) =>
      other is MarketHistoryKey &&
      other.typeId == typeId &&
      other.regionId == regionId;

  @override
  int get hashCode => Object.hash(typeId, regionId);
}

final marketHistoryProvider = FutureProvider.family<List<MarketHistoryEntry>,
    MarketHistoryKey>((ref, key) async {
  final repo = ref.watch(marketRepositoryProvider);
  return repo.fetchHistory(typeId: key.typeId, regionId: key.regionId);
});

/// CCP's rolling per-type average price for every published type, in
/// one shot. Cached server-side ~1h, so the family providers below
/// share a single network round-trip.
final marketGlobalPricesProvider = FutureProvider<Map<int, double>>((ref) {
  return ref.watch(marketRepositoryProvider).fetchGlobalPrices();
});

/// Latest reference price for [typeId] from `/markets/prices/`. Used
/// for header glances (e.g. the PLEX price next to the server status)
/// where a one-number-fits-all aggregate is preferable to paginating
/// the live order book — and necessary for items like PLEX that no
/// longer trade through the public market at all.
final marketLatestPriceProvider =
    FutureProvider.family<double?, int>((ref, typeId) async {
  final prices = await ref.watch(marketGlobalPricesProvider.future);
  return prices[typeId];
});
