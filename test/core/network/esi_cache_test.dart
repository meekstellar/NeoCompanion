import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/core/network/esi_cache.dart';

void main() {
  test('LRU eviction drops the least-recently-used entry first', () {
    final cache = EsiCache(maxEntries: 3);
    final future = DateTime.now().add(const Duration(minutes: 1));
    cache.put('a', CachedResponse(body: 'A', expiresAt: future));
    cache.put('b', CachedResponse(body: 'B', expiresAt: future));
    cache.put('c', CachedResponse(body: 'C', expiresAt: future));

    // touch 'a' so 'b' is now least-recently-used
    cache.get('a');

    cache.put('d', CachedResponse(body: 'D', expiresAt: future));

    expect(cache.get('a')?.body, 'A');
    expect(cache.get('b'), isNull);
    expect(cache.get('c')?.body, 'C');
    expect(cache.get('d')?.body, 'D');
  });

  test('isExpired flips once expiresAt is in the past', () {
    final cache = EsiCache();
    final past = DateTime.now().subtract(const Duration(seconds: 1));
    cache.put('k', CachedResponse(body: 'x', expiresAt: past));
    expect(cache.get('k')!.isExpired, isTrue);
  });

  test('key includes characterId so two characters cache independently', () {
    final cache = EsiCache();
    final k1 = cache.key(method: 'GET', url: '/foo', characterId: 1);
    final k2 = cache.key(method: 'GET', url: '/foo', characterId: 2);
    expect(k1, isNot(k2));
  });
}
