import '../../../core/network/esi_client.dart';
import 'dto/planet_layout.dart';
import 'dto/planet_summary.dart';

class PlanetRepository {
  PlanetRepository(this._esi);

  final EsiClient _esi;

  Future<List<PlanetSummary>> fetchColonies(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/planets/',
      characterId: characterId,
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(PlanetSummary.fromJson)
        .toList();
  }

  /// Pin / link / route layout for one colony.
  Future<PlanetLayout> fetchLayout(int characterId, int planetId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/planets/$planetId/',
      characterId: characterId,
    );
    return PlanetLayout.fromJson(res.data!);
  }
}
