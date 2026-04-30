import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locations/location_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'data/contract_repository.dart';
import 'data/dto/contract.dart';
import 'data/dto/contract_item.dart';

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return ContractRepository(ref.watch(esiClientProvider));
});

class ContractsData {
  const ContractsData({
    required this.contracts,
    required this.locationNames,
    required this.partyNames,
  });

  final List<Contract> contracts;
  final Map<int, String> locationNames;

  /// Issuer / assignee resolved to a display name where ESI lets us
  /// (characters, NPC corps, alliances). NPC ids the local SDE
  /// already knows about don't make a network round-trip.
  final Map<int, String> partyNames;
}

/// Loads the contract list for [characterId] and resolves all
/// referenced location ids (start/end stations and citadels) plus
/// counterparty ids through the same shared `LocationResolver` we use
/// elsewhere — so citadels in courier routes show their real name.
final contractsProvider =
    FutureProvider.family<ContractsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(contractRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);
  final resolver = ref.watch(locationResolverProvider(characterId));

  final contracts = await repo.fetchAll(characterId);

  final locationIds = <int>{
    for (final c in contracts) ...[
      if (c.startLocationId != null) c.startLocationId!,
      if (c.endLocationId != null) c.endLocationId!,
    ],
  };
  final partyIds = <int>{
    for (final c in contracts) ...[
      c.issuerId,
      if (c.assigneeId != null && c.assigneeId != 0) c.assigneeId!,
    ],
  };

  final locationFuture = resolver.resolve(locationIds);
  // Parties are characters / corps / alliances — all under the
  // structure threshold, so /universe/names/ handles them. Failures
  // are swallowed so the list still renders with raw ids.
  final partyFuture = partyIds.isEmpty
      ? Future.value(<int, String>{})
      : character
          .resolveNames(partyIds.toList())
          .then((list) => {for (final n in list) n.id: n.name})
          .catchError((_) => <int, String>{});

  final results = await Future.wait([locationFuture, partyFuture]);
  return ContractsData(
    contracts: contracts,
    locationNames: results[0],
    partyNames: results[1],
  );
});

/// Items on a single contract — fetched on demand from the detail
/// screen, never as part of the list load. Courier contracts and
/// contracts the character can't see the items of return null; the
/// detail screen renders that as a "no items" state.
class ContractItemsKey {
  const ContractItemsKey({required this.characterId, required this.contractId});
  final int characterId;
  final int contractId;

  @override
  bool operator ==(Object other) =>
      other is ContractItemsKey &&
      other.characterId == characterId &&
      other.contractId == contractId;

  @override
  int get hashCode => Object.hash(characterId, contractId);
}

final contractItemsProvider =
    FutureProvider.family<List<ContractItem>?, ContractItemsKey>((ref, key) {
  final repo = ref.watch(contractRepositoryProvider);
  return repo.fetchItems(key.characterId, key.contractId);
});
