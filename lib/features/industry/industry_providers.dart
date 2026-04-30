import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/dto/industry_job.dart';
import 'data/industry_repository.dart';

final industryRepositoryProvider = Provider<IndustryRepository>((ref) {
  return IndustryRepository(ref.watch(esiClientProvider));
});

class IndustryJobsData {
  const IndustryJobsData({
    required this.jobs,
    required this.locationNames,
  });

  final List<IndustryJob> jobs;
  final Map<int, String> locationNames;
}

final industryJobsProvider =
    FutureProvider.family<IndustryJobsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(industryRepositoryProvider);
  final resolver = ref.watch(locationResolverProvider(characterId));

  final jobs = await repo.fetchJobs(characterId);
  final locationNames = await resolver.resolve({
    for (final j in jobs) j.locationId,
  });

  return IndustryJobsData(jobs: jobs, locationNames: locationNames);
});
