import '../../../core/network/esi_client.dart';
import 'dto/wallet_journal_entry.dart';

class WalletRepository {
  WalletRepository(this._esi);

  final EsiClient _esi;

  Future<List<WalletJournalEntry>> fetchJournalPage(
    int characterId, {
    int page = 1,
  }) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/wallet/journal/',
      characterId: characterId,
      queryParameters: {'page': page},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(WalletJournalEntry.fromJson)
        .toList();
  }
}
