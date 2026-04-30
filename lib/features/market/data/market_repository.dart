import '../../../core/network/esi_client.dart';
import 'dto/market_history_entry.dart';
import 'dto/market_order.dart';

/// Default region for price-history lookups when the caller doesn't
/// specify one. The Forge holds Jita 4-4 and dwarfs every other
/// market hub by volume, so its prices are the canonical reference
/// EVE players quote each other.
const int kDefaultMarketRegionId = 10000002;

class MarketRepository {
  MarketRepository(this._esi);

  final EsiClient _esi;

  Future<List<MarketOrder>> fetchOpenOrders(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/orders/',
      characterId: characterId,
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(MarketOrder.fromJson)
        .toList();
  }

  /// Up to one year of daily price/volume history for [typeId] in
  /// [regionId]. Unauthenticated; ESI caches the response ~24h
  /// server-side, our `CacheInterceptor` honours that. Types that
  /// have never traded come back as an empty list.
  Future<List<MarketHistoryEntry>> fetchHistory({
    required int typeId,
    int regionId = kDefaultMarketRegionId,
  }) async {
    final res = await _esi.get<List<dynamic>>(
      '/markets/$regionId/history/',
      queryParameters: {'type_id': typeId},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(MarketHistoryEntry.fromJson)
        .toList();
  }
}
