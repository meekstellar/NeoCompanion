import '../../../core/network/esi_client.dart';
import 'dto/character_location.dart';
import 'dto/character_portrait.dart';
import 'dto/character_public_info.dart';
import 'dto/character_ship.dart';
import 'dto/universe_name.dart';

class CharacterRepository {
  CharacterRepository(this._esi);

  final EsiClient _esi;

  Future<CharacterPublicInfo> fetchPublic(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>('/characters/$characterId/');
    return CharacterPublicInfo.fromJson(res.data!);
  }

  Future<CharacterPortrait> fetchPortrait(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/portrait/',
    );
    return CharacterPortrait.fromJson(res.data!);
  }

  Future<CharacterLocation> fetchLocation(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/location/',
      characterId: characterId,
    );
    return CharacterLocation.fromJson(res.data!);
  }

  Future<CharacterShip> fetchShip(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/ship/',
      characterId: characterId,
    );
    return CharacterShip.fromJson(res.data!);
  }

  Future<double> fetchWalletBalance(int characterId) async {
    final res = await _esi.get<num>(
      '/characters/$characterId/wallet/',
      characterId: characterId,
    );
    return res.data!.toDouble();
  }

  /// Batch-resolves up to 1000 IDs of characters/corps/alliances/types/systems
  /// to their human-readable names. Public endpoint, no auth needed.
  Future<List<UniverseName>> resolveNames(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _esi.post<List<dynamic>>('/universe/names/', data: ids);
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(UniverseName.fromJson)
        .toList();
  }
}
