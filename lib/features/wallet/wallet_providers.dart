import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import 'data/dto/wallet_journal_entry.dart';
import 'data/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(esiClientProvider));
});

/// First page of the journal, ~most recent 2500 entries. Pagination beyond
/// page 1 is post-MVP — page 1 covers the "recent activity" use case.
final walletJournalProvider =
    FutureProvider.family<List<WalletJournalEntry>, int>((ref, characterId) {
  return ref
      .watch(walletRepositoryProvider)
      .fetchJournalPage(characterId, page: 1);
});
