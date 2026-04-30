import '../../features/characters/data/character_repository.dart';
import '../types/types_database.dart';

/// Resolves arbitrary EVE location ids — NPC stations, solar systems,
/// player citadels, corp/alliance/character ids — to display names.
///
/// Tries the local SDE first (solar systems, NPC stations resolve
/// without a network call), then partitions whatever's left by id
/// range and runs the two ESI naming endpoints in parallel:
///
///   * id < 100M → `/universe/names/` (NPC stations, characters,
///     corps, alliances; bisects on rejection so a single bad id
///     doesn't poison the rest of the batch).
///   * id ≥ 100M → authorized `/universe/structures/{id}/`, one call
///     per id; 403 / 404 become absent map entries instead of
///     throwing (foreign citadels we can't dock at stay "Unknown").
///
/// Per-batch failures are swallowed so the caller still gets a
/// partial result — the screens that depend on this would rather
/// render most names than fail wholesale.
class LocationResolver {
  LocationResolver({
    required this.typesDb,
    required this.character,
    required this.characterId,
  });

  final TypesDatabase typesDb;
  final CharacterRepository character;
  final int characterId;

  /// IDs at or above this value are player-anchored structures;
  /// anything below is in the public-id space (`/universe/names/`).
  static const int structureIdThreshold = 100000000;

  Future<Map<int, String>> resolve(Iterable<int> ids) async {
    final out = <int, String>{};
    final unresolved = <int>{};
    for (final id in ids) {
      final system = typesDb.lookupSystem(id);
      if (system != null) {
        out[id] = system;
        continue;
      }
      final station = typesDb.lookupStation(id);
      if (station != null) {
        out[id] = station;
        continue;
      }
      unresolved.add(id);
    }
    if (unresolved.isEmpty) return out;

    final nameableIds = <int>[];
    final structureIds = <int>[];
    for (final id in unresolved) {
      if (id >= structureIdThreshold) {
        structureIds.add(id);
      } else {
        nameableIds.add(id);
      }
    }
    await Future.wait<void>([
      if (nameableIds.isNotEmpty)
        character.resolveNames(nameableIds).then((resolved) {
          for (final n in resolved) {
            out[n.id] = n.name;
          }
        }).catchError((_) {/* keep partial results */}),
      if (structureIds.isNotEmpty)
        character.fetchStructures(characterId, structureIds).then((resolved) {
          for (final entry in resolved.entries) {
            out[entry.key] = entry.value.name;
          }
        }).catchError((_) {/* keep partial results */}),
    ]);
    return out;
  }
}
