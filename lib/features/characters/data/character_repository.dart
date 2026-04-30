import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/network/esi_client.dart';
import 'dto/character_attributes.dart';
import 'dto/character_location.dart';
import 'dto/character_portrait.dart';
import 'dto/character_public_info.dart';
import 'dto/character_ship.dart';
import 'dto/structure_info.dart';
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

  Future<CharacterAttributes> fetchAttributes(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/attributes/',
      characterId: characterId,
    );
    return CharacterAttributes.fromJson(res.data!);
  }

  Future<List<int>> fetchImplants(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/implants/',
      characterId: characterId,
    );
    return res.data!.map((e) => (e as num).toInt()).toList();
  }

  /// Batch-resolves IDs of characters/corps/alliances/types/systems to
  /// human-readable names. Splits into chunks of 1000 (the ESI hard cap)
  /// and bisects any chunk that comes back as an error so a single bad
  /// id (typically a player-owned structure) doesn't poison the rest.
  Future<List<UniverseName>> resolveNames(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final result = <UniverseName>[];
    const maxBatch = 1000;
    for (var i = 0; i < ids.length; i += maxBatch) {
      final chunk = ids.sublist(i, math.min(i + maxBatch, ids.length));
      await _resolveChunk(chunk, result);
    }
    return result;
  }

  Future<void> _resolveChunk(List<int> ids, List<UniverseName> out) async {
    if (ids.isEmpty) return;
    try {
      final res = await _esi.post<List<dynamic>>('/universe/names/', data: ids);
      out.addAll(
        res.data!.cast<Map<String, dynamic>>().map(UniverseName.fromJson),
      );
    } on DioException {
      if (ids.length == 1) {
        // Single id rejected — drop it silently, the UI will show #id.
        return;
      }
      final mid = ids.length ~/ 2;
      await _resolveChunk(ids.sublist(0, mid), out);
      await _resolveChunk(ids.sublist(mid), out);
    }
  }

  /// Resolves a single player-anchored structure (citadel) via the
  /// authorized `/universe/structures/{id}/` endpoint. Returns null on
  /// 403 (no docking access — common for foreign citadels) or 404
  /// (already deleted). Other Dio errors propagate.
  Future<StructureInfo?> fetchStructure(int characterId, int structureId) async {
    try {
      final res = await _esi.get<Map<String, dynamic>>(
        '/universe/structures/$structureId/',
        characterId: characterId,
      );
      return StructureInfo.fromJson(structureId, res.data!);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 404) return null;
      rethrow;
    }
  }

  /// Resolves many structures in parallel. Per-id failures (no access,
  /// gone) become absent map entries instead of taking down the batch.
  Future<Map<int, StructureInfo>> fetchStructures(
      int characterId, List<int> structureIds) async {
    if (structureIds.isEmpty) return const {};
    final results = await Future.wait([
      for (final id in structureIds)
        fetchStructure(characterId, id).then<StructureInfo?>((s) => s,
            onError: (_) => null),
    ]);
    final out = <int, StructureInfo>{};
    for (final s in results) {
      if (s != null) out[s.structureId] = s;
    }
    return out;
  }

  /// Reverse of [resolveNames]: maps human-readable names to type/system/etc
  /// IDs via /universe/ids/. Returns a flat name → id map covering all
  /// matched categories. Names that don't resolve are simply absent.
  Future<Map<String, int>> resolveIds(List<String> names) async {
    if (names.isEmpty) return const {};
    final res = await _esi.post<Map<String, dynamic>>(
      '/universe/ids/',
      data: names,
    );
    final result = <String, int>{};
    for (final category in res.data!.values) {
      if (category is List) {
        for (final entry in category) {
          if (entry is Map<String, dynamic>) {
            result[entry['name'] as String] = (entry['id'] as num).toInt();
          }
        }
      }
    }
    return result;
  }
}
