import '../../../core/network/esi_client.dart';
import '../domain/parsed_to_payload.dart';
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

  /// POSTs a new fitting and returns the assigned fitting_id.
  Future<int> create(int characterId, FittingPayload payload) async {
    final res = await _esi.post<Map<String, dynamic>>(
      '/characters/$characterId/fittings/',
      data: payload.toJson(),
      characterId: characterId,
    );
    return (res.data!['fitting_id'] as num).toInt();
  }
}
