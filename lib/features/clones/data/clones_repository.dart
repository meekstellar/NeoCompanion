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

  /// Returns the type ids of implants currently slotted in the
  /// character's active clone (the one they're flying with). Empty
  /// list when the character has no implants in.
  Future<List<int>> fetchActiveImplants(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/implants/',
      characterId: characterId,
    );
    return res.data!.cast<num>().map((n) => n.toInt()).toList();
  }
}
