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

  /// `typeId → average_price` from `/markets/prices/`. Covers every
  /// published type in one unauth call (cached server-side ~1h),
  /// including ones that no longer post public orders — PLEX, in
  /// particular, was moved to a private vault, so the regional orders
  /// endpoint returns nothing for it but this aggregate still reports
  /// CCP's rolling average. Also exposes `adjusted_price`, but for a
  /// header glance the average is the right number.
  Future<Map<int, double>> fetchGlobalPrices() async {
    final res = await _esi.get<List<dynamic>>('/markets/prices/');
    final out = <int, double>{};
    for (final raw in res.data ?? const []) {
      final m = (raw as Map).cast<String, dynamic>();
      final tid = (m['type_id'] as num?)?.toInt();
      final avg = (m['average_price'] as num?)?.toDouble();
      if (tid == null || avg == null) continue;
      out[tid] = avg;
    }
    return out;
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
