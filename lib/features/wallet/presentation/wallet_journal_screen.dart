import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/wallet_journal_entry.dart';
import '../wallet_providers.dart';

class WalletJournalScreen extends ConsumerStatefulWidget {
  const WalletJournalScreen({super.key, required this.characterId});

  final int characterId;

  @override
  ConsumerState<WalletJournalScreen> createState() =>
      _WalletJournalScreenState();
}

class _WalletJournalScreenState extends ConsumerState<WalletJournalScreen> {
  String? _filterRefType;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(walletJournalProvider(widget.characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet journal')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () =>
              ref.invalidate(walletJournalProvider(widget.characterId)),
        ),
        data: (entries) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(walletJournalProvider(widget.characterId)),
          child: _build(entries),
        ),
      ),
    );
  }

  Widget _build(List<WalletJournalEntry> all) {
    final refTypes = <String>{for (final e in all) e.refType}.toList()..sort();
    final filtered = _filterRefType == null
        ? all
        : all.where((e) => e.refType == _filterRefType).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterRefType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...refTypes.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t,
                        child: Text(_humanize(t)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterRefType = v),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${filtered.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No entries'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, i) =>
                      _JournalRow(entry: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({required this.entry});
  final WalletJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.amount >= 0;
    final color =
        isCredit ? Colors.greenAccent : Theme.of(context).colorScheme.error;
    final sign = isCredit ? '+' : '−';

    return ListTile(
      dense: true,
      title: Text(_humanize(entry.refType)),
      subtitle: Text(
        [
          _formatDate(entry.date),
          if (entry.description != null && entry.description!.isNotEmpty)
            entry.description!,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$sign${_formatIsk(entry.amount.abs())}',
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

String _humanize(String refType) {
  return refType
      .split('_')
      .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
      .join(' ');
}

String _formatIsk(double v) =>
    '${NumberFormat('#,##0.00', 'en_US').format(v)} ISK';

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return DateFormat('MMM d, HH:mm').format(local);
}
