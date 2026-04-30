import '../../../core/network/esi_client.dart';
import 'dto/clones_data.dart';

class ClonesRepository {
  ClonesRepository(this._esi);

  final EsiClient _esi;

  Future<ClonesData> fetch(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/clones/',
      characterId: characterId,
    );
    return ClonesData.fromJson(res.data!);
  }
}
