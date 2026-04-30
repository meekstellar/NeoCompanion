import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/clones_repository.dart';
import 'data/dto/clones_data.dart';

final clonesRepositoryProvider = Provider<ClonesRepository>((ref) {
  return ClonesRepository(ref.watch(esiClientProvider));
});

class ClonesView {
  const ClonesView({
    required this.data,
    required this.locationNames,
  });

  final ClonesData data;
  final Map<int, String> locationNames;
}

final jumpClonesProvider =
    FutureProvider.family<ClonesView, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(clonesRepositoryProvider);
  final resolver = ref.watch(locationResolverProvider(characterId));

  final data = await repo.fetch(characterId);

  final locationNames = await resolver.resolve(<int>{
    if (data.homeLocation != null) data.homeLocation!.locationId,
    for (final c in data.jumpClones) c.location.locationId,
  });

  return ClonesView(data: data, locationNames: locationNames);
});
