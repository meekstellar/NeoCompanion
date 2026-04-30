import '../../../core/network/esi_client.dart';
import 'dto/asset_item.dart';

class AssetRepository {
  AssetRepository(this._esi);

  final EsiClient _esi;

  /// Fetches every page of `/characters/{id}/assets/`. Page 1 comes
  /// back first (so we know `x-pages`), the rest fire in parallel.
  Future<List<AssetItem>> fetchAll(int characterId,
      {int maxPages = 20}) async {
    final first = await _fetchPage(characterId, 1);
    final totalPages =
        (int.tryParse(first.xPages ?? '1') ?? 1).clamp(1, maxPages);
    if (totalPages == 1) return first.items;

    final rest = await Future.wait([
      for (var p = 2; p <= totalPages; p++) _fetchPage(characterId, p),
    ]);
    return [
      ...first.items,
      for (final r in rest) ...r.items,
    ];
  }

  Future<_PageResult> _fetchPage(int characterId, int page) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/assets/',
      characterId: characterId,
      queryParameters: {'page': page},
    );
    return _PageResult(
      items: res.data!.cast<Map<String, dynamic>>().map(AssetItem.fromJson).toList(),
      xPages: res.headers.value('x-pages'),
    );
  }
}

class _PageResult {
  _PageResult({required this.items, required this.xPages});
  final List<AssetItem> items;
  final String? xPages;
}
