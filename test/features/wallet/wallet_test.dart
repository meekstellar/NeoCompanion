import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocompanion/features/wallet/data/dto/wallet_journal_entry.dart';
import 'package:neocompanion/features/wallet/presentation/wallet_journal_screen.dart';
import 'package:neocompanion/features/wallet/wallet_providers.dart';

void main() {
  group('WalletJournalEntry', () {
    test('parses a credit entry', () {
      final dto = WalletJournalEntry.fromJson({
        'id': 12345,
        'ref_type': 'player_trading',
        'date': '2026-04-29T13:00:00Z',
        'amount': 1500000.0,
        'balance': 50000000.0,
        'description': 'Sale to alt',
        'first_party_id': 90000001,
        'second_party_id': 90000002,
      });
      expect(dto.id, 12345);
      expect(dto.refType, 'player_trading');
      expect(dto.amount, 1500000.0);
      expect(dto.balance, 50000000.0);
      expect(dto.firstPartyId, 90000001);
    });

    test('treats missing optional fields as null', () {
      final dto = WalletJournalEntry.fromJson({
        'id': 1,
        'ref_type': 'bounty_prizes',
        'date': '2026-01-01T00:00:00Z',
        'amount': -50.0,
      });
      expect(dto.balance, isNull);
      expect(dto.description, isNull);
      expect(dto.firstPartyId, isNull);
      expect(dto.tax, isNull);
    });
  });

  testWidgets('journal screen renders entries and filters by type',
      (tester) async {
    final entries = [
      WalletJournalEntry(
        id: 1,
        refType: 'player_trading',
        date: DateTime(2026, 4, 29, 13),
        amount: 1500000,
      ),
      WalletJournalEntry(
        id: 2,
        refType: 'bounty_prizes',
        date: DateTime(2026, 4, 29, 14),
        amount: -250000,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletJournalProvider(11).overrideWith((_) async => entries),
        ],
        child: const MaterialApp(
          home: WalletJournalScreen(characterId: 11),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player Trading'), findsOneWidget);
    expect(find.text('Bounty Prizes'), findsOneWidget);
    // 2 entries total before filtering
    expect(find.text('2'), findsOneWidget);

    // Filter to player_trading only
    await tester.tap(find.text('All types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player Trading').last);
    await tester.pumpAndSettle();

    expect(find.text('Bounty Prizes'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
