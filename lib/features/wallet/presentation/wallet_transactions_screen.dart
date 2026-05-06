import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database_providers.dart';
import '../data/dto/wallet_transaction_entry.dart';
import '../wallet_providers.dart';

class WalletTransactionsScreen extends ConsumerWidget {
  const WalletTransactionsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletTransactionsProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () =>
              ref.invalidate(walletTransactionsProvider(characterId)),
        ),
        data: (entries) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(walletTransactionsProvider(characterId)),
          child: entries.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 64),
                  Center(child: Text('No transactions')),
                ])
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (_, i) => _TransactionRow(entry: entries[i]),
                ),
        ),
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.entry});
  final WalletTransactionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(typesDatabaseProvider);
    final name = db.lookup(entry.typeId) ?? '#${entry.typeId}';
    final isBuy = entry.isBuy;
    final color = isBuy ? theme.colorScheme.error : Colors.greenAccent;
    final sign = isBuy ? '−' : '+';

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TypeDetailScreen(typeId: entry.typeId),
        ),
      ),
      leading: EveTypeImage(
        typeId: entry.typeId,
        size: 40,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(
        '${NumberFormat('#,##0', 'en_US').format(entry.quantity)} × $name',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatDate(entry.date)} · ${_formatIsk(entry.unitPrice)} ISK',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$sign${_formatIsk(entry.total)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(describeEsiError(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _formatIsk(double v) => NumberFormat('#,##0.00', 'en_US').format(v);

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return DateFormat('MMM d, HH:mm').format(local);
}
