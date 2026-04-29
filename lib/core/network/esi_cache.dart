/// One cached HTTP response: body, the ETag if the server provided one,
/// and the moment after which we must revalidate.
class CachedResponse {
  CachedResponse({
    required this.body,
    required this.expiresAt,
    this.etag,
  });

  final Object? body;
  final DateTime expiresAt;
  final String? etag;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}

/// In-memory LRU keyed by (method, URL, characterId). Used by
/// CacheInterceptor; tests instantiate it directly.
class EsiCache {
  EsiCache({this.maxEntries = 100});

  final int maxEntries;
  final Map<String, CachedResponse> _entries = {};
  final List<String> _lru = [];

  String key({
    required String method,
    required String url,
    int? characterId,
  }) =>
      '$method|$url|${characterId ?? ''}';

  CachedResponse? get(String key) {
    final entry = _entries[key];
    if (entry != null) {
      _lru
        ..remove(key)
        ..add(key);
    }
    return entry;
  }

  void put(String key, CachedResponse entry) {
    _entries[key] = entry;
    _lru
      ..remove(key)
      ..add(key);
    while (_entries.length > maxEntries) {
      final oldest = _lru.removeAt(0);
      _entries.remove(oldest);
    }
  }

  int get length => _entries.length;

  void clear() {
    _entries.clear();
    _lru.clear();
  }
}
