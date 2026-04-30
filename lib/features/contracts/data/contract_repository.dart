import 'package:dio/dio.dart';

import '../../../core/network/esi_client.dart';
import 'dto/contract.dart';
import 'dto/contract_item.dart';

class ContractRepository {
  ContractRepository(this._esi);

  final EsiClient _esi;

  /// Fetches every page of `/characters/{id}/contracts/`. The first
  /// page comes back first so we know `x-pages`; the rest fire in
  /// parallel — same shape as the asset repository.
  Future<List<Contract>> fetchAll(int characterId, {int maxPages = 20}) async {
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
      '/characters/$characterId/contracts/',
      characterId: characterId,
      queryParameters: {'page': page},
    );
    return _PageResult(
      items: res.data!
          .cast<Map<String, dynamic>>()
          .map(Contract.fromJson)
          .toList(),
      xPages: res.headers.value('x-pages'),
    );
  }

  /// Items on one item-exchange or auction contract. Courier
  /// contracts have no items endpoint — ESI 404s — so callers should
  /// only hit this for the right [Contract.type]. Returns `null` on
  /// 404 / 403 so the detail screen can render gracefully.
  Future<List<ContractItem>?> fetchItems(int characterId, int contractId) async {
    try {
      final res = await _esi.get<List<dynamic>>(
        '/characters/$characterId/contracts/$contractId/items/',
        characterId: characterId,
      );
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(ContractItem.fromJson)
          .toList();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403 || code == 404) return null;
      rethrow;
    }
  }
}

class _PageResult {
  _PageResult({required this.items, required this.xPages});
  final List<Contract> items;
  final String? xPages;
}
