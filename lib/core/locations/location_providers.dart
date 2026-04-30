import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/character_providers.dart';
import '../types/types_database_providers.dart';
import 'location_resolver.dart';

/// Per-character resolver. Keyed by character id because structure
/// resolution requires the character's auth token.
final locationResolverProvider =
    Provider.family<LocationResolver, int>((ref, characterId) {
  return LocationResolver(
    typesDb: ref.watch(typesDatabaseProvider),
    character: ref.watch(characterRepositoryProvider),
    characterId: characterId,
  );
});
