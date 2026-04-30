import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database_providers.dart';
import '../characters/character_providers.dart';
import 'data/dto/loyalty_balance.dart';
import 'data/loyalty_repository.dart';

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(ref.watch(esiClientProvider));
});

class LoyaltyData {
  const LoyaltyData({
    required this.balances,
    required this.corpNames,
  });

  final List<LoyaltyBalance> balances;
  final Map<int, String> corpNames;
}

final loyaltyProvider =
    FutureProvider.family<LoyaltyData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(loyaltyRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final balances = await repo.fetchBalances(characterId);

  // NPC corp names live in the SDE for the most part. Anything left
  // over (e.g. faction-warfare militia corps that the SDE leaves
  // out) goes through `/universe/names/` in one batched call.
  final corpNames = <int, String>{};
  final unresolved = <int>[];
  for (final b in balances) {
    final local = typesDb.lookupNpcCorporation(b.corporationId);
    if (local != null) {
      corpNames[b.corporationId] = local;
    } else {
      unresolved.add(b.corporationId);
    }
  }
  if (unresolved.isNotEmpty) {
    try {
      final names = await character.resolveNames(unresolved);
      for (final n in names) {
        corpNames[n.id] = n.name;
      }
    } catch (_) {
      // Missing names render as #id; not load-bearing.
    }
  }

  return LoyaltyData(balances: balances, corpNames: corpNames);
});
