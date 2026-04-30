import '../../../core/network/esi_client.dart';
import 'dto/loyalty_balance.dart';

class LoyaltyRepository {
  LoyaltyRepository(this._esi);

  final EsiClient _esi;

  Future<List<LoyaltyBalance>> fetchBalances(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/loyalty/points/',
      characterId: characterId,
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(LoyaltyBalance.fromJson)
        .toList();
  }
}
