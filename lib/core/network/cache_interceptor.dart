import 'dart:io';

import 'package:dio/dio.dart';

import 'esi_cache.dart';
import 'esi_constants.dart';

const _cachedBodyKey = 'esiCachedBody';
const _cachedEtagKey = 'esiCachedEtag';
const _cachedHeadersKey = 'esiCachedHeaders';

/// Cache-aware Dio interceptor:
///  * fresh entry → short-circuits to cached response (no network)
///  * stale entry with ETag → attaches `If-None-Match`
///  * 304 from server → returns the cached body and refreshes expiry
///  * 200 with `ETag`/`Expires` → stores for next time
class CacheInterceptor extends Interceptor {
  CacheInterceptor(this._cache);

  final EsiCache _cache;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (options.method != 'GET') {
      return handler.next(options);
    }
    final key = _cacheKey(options);
    final entry = _cache.get(key);
    if (entry == null) {
      return handler.next(options);
    }

    if (!entry.isExpired) {
      handler.resolve(_responseFromCache(options, entry));
      return;
    }

    if (entry.etag != null) {
      options.headers['If-None-Match'] = entry.etag!;
      options.extra[_cachedBodyKey] = entry.body;
      options.extra[_cachedEtagKey] = entry.etag!;
      // Snapshot the headers (incl. x-pages) into the request — if the
      // cache is evicted between request and 304 we still have them.
      options.extra[_cachedHeadersKey] = entry.headers;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (options.method == 'GET' && response.statusCode == 200) {
      _cache.put(
        _cacheKey(options),
        CachedResponse(
          body: response.data,
          expiresAt: _parseExpires(response.headers.value('expires')),
          etag: response.headers.value('etag'),
          headers: _captureHeaders(response.headers),
        ),
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final options = err.requestOptions;
    final cachedBody = options.extra[_cachedBodyKey];
    if (response?.statusCode == 304 && cachedBody != null) {
      final etag = response!.headers.value('etag') ??
          options.extra[_cachedEtagKey] as String?;
      // 304 keeps the previously-cached headers (incl. x-pages); prefer
      // the snapshot we stashed at request time so an eviction between
      // request and 304 doesn't drop pagination metadata.
      final previous = _cache.get(_cacheKey(options));
      final headers = (options.extra[_cachedHeadersKey]
              as Map<String, List<String>>?) ??
          previous?.headers ??
          const {};
      final entry = CachedResponse(
        body: cachedBody,
        expiresAt: _parseExpires(response.headers.value('expires')),
        etag: etag,
        headers: headers,
      );
      _cache.put(_cacheKey(options), entry);
      handler.resolve(_responseFromCache(options, entry));
      return;
    }
    handler.next(err);
  }

  String _cacheKey(RequestOptions options) {
    return _cache.key(
      method: options.method,
      url: options.uri.toString(),
      characterId: options.extra[esiCharacterIdKey] as int?,
    );
  }

  Response<dynamic> _responseFromCache(
    RequestOptions options,
    CachedResponse entry,
  ) {
    return Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: entry.body,
      headers: Headers.fromMap(entry.headers),
      extra: {'fromCache': true},
    );
  }

  /// Stash only the response headers we may need to replay; full
  /// header maps would balloon the in-memory cache.
  static const _replayHeaders = <String>{
    'x-pages',
    'expires',
    'etag',
    'last-modified',
  };

  Map<String, List<String>> _captureHeaders(Headers headers) {
    final out = <String, List<String>>{};
    for (final name in _replayHeaders) {
      final values = headers[name];
      if (values != null && values.isNotEmpty) out[name] = List.of(values);
    }
    return out;
  }

  DateTime _parseExpires(String? raw) {
    if (raw != null) {
      try {
        return HttpDate.parse(raw);
      } catch (_) {
        // fall through
      }
    }
    return DateTime.now().add(const Duration(seconds: 60));
  }
}
