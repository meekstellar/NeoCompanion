import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/core/auth/token_set.dart';

void main() {
  TokenSet sample({DateTime? expiresAt}) => TokenSet(
        characterId: 90000001,
        characterName: 'CCP Falcon',
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 10)),
        scopes: const ['esi-skills.read_skillqueue.v1', 'publicData'],
      );

  test('roundtrips through JSON', () {
    final original = sample();
    final restored = TokenSet.decode(original.encode());
    expect(restored.characterId, original.characterId);
    expect(restored.characterName, original.characterName);
    expect(restored.accessToken, original.accessToken);
    expect(restored.refreshToken, original.refreshToken);
    expect(restored.expiresAt, original.expiresAt);
    expect(restored.scopes, original.scopes);
  });

  test('isExpired is true past the leeway window', () {
    final t = sample(expiresAt: DateTime.now().add(const Duration(seconds: 30)));
    expect(t.isExpired, isTrue);
  });

  test('isExpired is false when far from expiry', () {
    final t = sample(expiresAt: DateTime.now().add(const Duration(minutes: 30)));
    expect(t.isExpired, isFalse);
  });

  test('copyWith preserves identity fields', () {
    final t = sample();
    final copy = t.copyWith(accessToken: 'new');
    expect(copy.characterId, t.characterId);
    expect(copy.refreshToken, t.refreshToken);
    expect(copy.accessToken, 'new');
    expect(copy.scopes, t.scopes);
  });
}
