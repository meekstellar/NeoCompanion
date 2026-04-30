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

  /// Resolves player-set names for the given singleton item ids via
  /// `POST /characters/{id}/assets/names/`. ESI caps each request at 1000
  /// ids, so [itemIds] is chunked and sent in parallel. Items the player
  /// hasn't renamed come back as "None" — those are dropped.
  Future<Map<int, String>> fetchNames(
      int characterId, List<int> itemIds) async {
    if (itemIds.isEmpty) return const {};
    const chunkSize = 1000;
    final chunks = <List<int>>[
      for (var i = 0; i < itemIds.length; i += chunkSize)
        itemIds.sublist(
            i, i + chunkSize > itemIds.length ? itemIds.length : i + chunkSize),
    ];
    final results = await Future.wait(chunks.map((chunk) => _fetchNamesChunk(
          characterId,
          chunk,
        )));
    final out = <int, String>{};
    for (final m in results) {
      out.addAll(m);
    }
    return out;
  }

  Future<Map<int, String>> _fetchNamesChunk(
      int characterId, List<int> itemIds) async {
    try {
      final res = await _esi.post<List<dynamic>>(
        '/characters/$characterId/assets/names/',
        characterId: characterId,
        data: itemIds,
      );
      final out = <int, String>{};
      for (final raw in res.data ?? const []) {
        final m = (raw as Map).cast<String, dynamic>();
        final id = (m['item_id'] as num?)?.toInt();
        final name = m['name'] as String?;
        if (id == null || name == null || name.isEmpty || name == 'None') {
          continue;
        }
        out[id] = name;
      }
      return out;
    } catch (_) {
      // A single chunk failing shouldn't take down the whole batch — names
      // are nice-to-have, not required to render assets.
      return const {};
    }
  }
}

class _PageResult {
  _PageResult({required this.items, required this.xPages});
  final List<AssetItem> items;
  final String? xPages;
}
