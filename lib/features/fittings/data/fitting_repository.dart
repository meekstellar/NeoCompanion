import '../../../core/network/esi_client.dart';
import 'dto/fitting.dart';

class FittingRepository {
  FittingRepository(this._esi);

  final EsiClient _esi;

  Future<List<Fitting>> fetchAll(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/fittings/',
      characterId: characterId,
    );
    return res.data!.cast<Map<String, dynamic>>().map(Fitting.fromJson).toList();
  }
}
