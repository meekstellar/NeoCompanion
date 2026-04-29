import '../../../core/network/esi_client.dart';
import 'dto/asset_item.dart';

class AssetRepository {
  AssetRepository(this._esi);

  final EsiClient _esi;

  /// Walks all pages of /characters/{id}/assets/ until the X-Pages
  /// header says we're done. Capped at [maxPages] to keep wallet-of-jita
  /// outliers from blocking the UI for minutes.
  Future<List<AssetItem>> fetchAll(int characterId, {int maxPages = 20}) async {
    final all = <AssetItem>[];
    for (var page = 1; page <= maxPages; page++) {
      final res = await _esi.get<List<dynamic>>(
        '/characters/$characterId/assets/',
        characterId: characterId,
        queryParameters: {'page': page},
      );
      all.addAll(
        res.data!.cast<Map<String, dynamic>>().map(AssetItem.fromJson),
      );
      final totalPages =
          int.tryParse(res.headers.value('x-pages') ?? '1') ?? 1;
      if (page >= totalPages) break;
    }
    return all;
  }
}
