import '../../../core/network/esi_client.dart';
import 'dto/market_order.dart';

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
}
