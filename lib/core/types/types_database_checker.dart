import 'package:dio/dio.dart';

import '../network/esi_constants.dart';
import 'types_database.dart';

/// Lightweight freshness probe: pings /universe/types/?page=1 with the
/// stored ETag in `If-None-Match`. CCP returns 304 when nothing has
/// changed; otherwise we look at X-Pages and the new ETag to decide
/// whether the local DB is out of date.
///
/// Uses its own bare Dio instance so the result skips our cache layer —
/// the cache would otherwise serve the previously-fetched response and
/// hide upstream changes.
class TypesDatabaseChecker {
  TypesDatabaseChecker({
    required TypesDatabase database,
    required String compatibilityDate,
    Dio? dio,
  })  : _database = database,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = esiBaseUrl
      ..headers[Headers.acceptHeader] = 'application/json'
      ..headers['User-Agent'] = esiUserAgent
      ..headers['X-Compatibility-Date'] = compatibilityDate;
  }

  final TypesDatabase _database;
  final Dio _dio;

  /// `true` when the local DB still matches what CCP serves; `false`
  /// when the user should be prompted to update. Errors propagate so
  /// the caller can hide the banner on transient network failure.
  Future<bool> isFresh() async {
    if (!_database.isReady) return false;

    final stored = _database.firstPageEtag;
    final res = await _dio.get<List<dynamic>>(
      '/universe/types/',
      queryParameters: {'page': 1},
      options: Options(
        headers: stored == null ? null : {'If-None-Match': stored},
        validateStatus: (s) => s == 200 || s == 304,
      ),
    );

    if (res.statusCode == 304) return true;

    final newEtag = res.headers.value('etag');
    final newPages =
        int.tryParse(res.headers.value('x-pages') ?? '1') ?? 1;
    if (newEtag == stored && newPages == _database.pageCount) return true;
    return false;
  }
}
