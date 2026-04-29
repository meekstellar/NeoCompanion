import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/core/auth/scope_compatibility.dart';

void main() {
  test('returns empty when all required scopes are present', () {
    final missing = missingScopes(
      have: ['publicData', 'esi-skills.read_skills.v1'],
      required: ['publicData', 'esi-skills.read_skills.v1'],
    );
    expect(missing, isEmpty);
  });

  test('returns the missing subset preserving required order', () {
    final missing = missingScopes(
      have: ['publicData', 'esi-wallet.read_character_wallet.v1'],
      required: [
        'publicData',
        'esi-skills.read_skillqueue.v1',
        'esi-wallet.read_character_wallet.v1',
        'esi-location.read_location.v1',
      ],
    );
    expect(missing, [
      'esi-skills.read_skillqueue.v1',
      'esi-location.read_location.v1',
    ]);
  });

  test('extra granted scopes are ignored', () {
    final missing = missingScopes(
      have: ['publicData', 'esi-mail.read_mail.v1'],
      required: ['publicData'],
    );
    expect(missing, isEmpty);
  });

  test('returns the entire required list when nothing is granted', () {
    final missing = missingScopes(
      have: const <String>[],
      required: ['a', 'b'],
    );
    expect(missing, ['a', 'b']);
  });
}
