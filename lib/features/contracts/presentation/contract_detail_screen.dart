import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import '../contract_providers.dart';
import '../data/dto/contract.dart';
import '../data/dto/contract_item.dart';

class ContractDetailScreen extends ConsumerWidget {
  const ContractDetailScreen({
    super.key,
    required this.contract,
    required this.data,
    required this.characterId,
  });

  final Contract contract;
  final ContractsData data;
  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(contract.title.isNotEmpty
            ? contract.title
            : 'Contract #${contract.contractId}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(contract: contract, data: data),
          const SizedBox(height: 16),
          _Money(contract: contract),
          const SizedBox(height: 16),
          _Dates(contract: contract),
          if (!contract.isCourier) ...[
            const SizedBox(height: 16),
            _Items(
              characterId: characterId,
              contractId: contract.contractId,
              db: db,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.contract, required this.data});
  final Contract contract;
  final ContractsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issuer = data.partyNames[contract.issuerId] ??
        '#${contract.issuerId}';
    final assignee = contract.assigneeId == null || contract.assigneeId == 0
        ? null
        : (data.partyNames[contract.assigneeId!] ?? '#${contract.assigneeId}');
    final start = contract.startLocationId == null
        ? null
        : (data.locationNames[contract.startLocationId!] ?? 'Unknown');
    final end = contract.endLocationId == null
        ? null
        : (data.locationNames[contract.endLocationId!] ?? 'Unknown');

    final lines = <Widget>[
      _row(theme, 'Type', _typeLabel(contract.type)),
      _row(theme, 'Status', _statusLabel(contract.status)),
      _row(theme, 'Availability', _availabilityLabel(contract.availability)),
      _row(theme, 'Issuer', issuer),
      if (assignee != null) _row(theme, 'Assignee', assignee),
      if (start != null) _row(theme, 'Start', start),
      if (end != null) _row(theme, 'End', end),
      if (contract.volume > 0)
        _row(theme, 'Volume',
            '${NumberFormat('#,##0.##', 'en_US').format(contract.volume)} m³'),
    ];

    return _Card(
      title: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lines,
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.contract});
  final Contract contract;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    if (contract.price > 0) {
      rows.add(_row(theme, 'Price', _isk(contract.price)));
    }
    if (contract.reward > 0) {
      rows.add(_row(theme, 'Reward', _isk(contract.reward)));
    }
    if (contract.collateral > 0) {
      rows.add(_row(theme, 'Collateral', _isk(contract.collateral)));
    }
    if (contract.buyout > 0) {
      rows.add(_row(theme, 'Buyout', _isk(contract.buyout)));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'Money',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _Dates extends StatelessWidget {
  const _Dates({required this.contract});
  final Contract contract;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm', 'en_US');
    final rows = <Widget>[
      _row(theme, 'Issued', fmt.format(contract.dateIssued.toLocal())),
      _row(theme, 'Expires', fmt.format(contract.dateExpired.toLocal())),
      if (contract.dateAccepted != null)
        _row(theme, 'Accepted', fmt.format(contract.dateAccepted!.toLocal())),
      if (contract.dateCompleted != null)
        _row(theme, 'Completed',
            fmt.format(contract.dateCompleted!.toLocal())),
      if (contract.daysToComplete != null && contract.daysToComplete! > 0)
        _row(theme, 'Days to complete', '${contract.daysToComplete}'),
    ];
    return _Card(
      title: 'Timing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _Items extends ConsumerWidget {
  const _Items({
    required this.characterId,
    required this.contractId,
    required this.db,
  });

  final int characterId;
  final int contractId;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractItemsProvider(
      ContractItemsKey(characterId: characterId, contractId: contractId),
    ));
    return async.when(
      loading: () => const _Card(
        title: 'Items',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _Card(
        title: 'Items',
        child: Text(describeEsiError(e)),
      ),
      data: (items) {
        if (items == null || items.isEmpty) {
          return const _Card(
            title: 'Items',
            child: Text('No items'),
          );
        }
        // ESI mixes "for sale" and "requested in return" lines on the
        // same response. Split them so the user can see both halves of
        // a "buy X for Y" trade clearly.
        final included = items.where((i) => i.isIncluded).toList();
        final requested = items.where((i) => !i.isIncluded).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (included.isNotEmpty) ...[
              _Card(
                title: requested.isEmpty ? 'Items' : 'Offered',
                child: _ItemList(items: included, db: db),
              ),
              if (requested.isNotEmpty) const SizedBox(height: 16),
            ],
            if (requested.isNotEmpty)
              _Card(
                title: 'Requested',
                child: _ItemList(items: requested, db: db),
              ),
          ],
        );
      },
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.db});
  final List<ContractItem> items;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qty = NumberFormat('#,##0', 'en_US');
    return Column(
      children: [
        for (final i in items)
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TypeDetailScreen(typeId: i.typeId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  EveTypeImage(
                    typeId: i.typeId,
                    size: 32,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      db.lookup(i.typeId) ?? '#${i.typeId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (i.isBlueprintCopy)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('BPC',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          )),
                    ),
                  Text(
                    '×${qty.format(i.quantity)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _row(ThemeData theme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

String _typeLabel(String t) {
  switch (t) {
    case 'item_exchange':
      return 'Item exchange';
    case 'auction':
      return 'Auction';
    case 'courier':
      return 'Courier';
    case 'loan':
      return 'Loan';
    default:
      return t;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'outstanding':
      return 'Outstanding';
    case 'in_progress':
      return 'In progress';
    case 'finished_issuer':
    case 'finished_contractor':
    case 'finished':
      return 'Finished';
    case 'cancelled':
      return 'Cancelled';
    case 'rejected':
      return 'Rejected';
    case 'failed':
      return 'Failed';
    case 'deleted':
      return 'Deleted';
    case 'reversed':
      return 'Reversed';
    default:
      return s;
  }
}

String _availabilityLabel(String a) {
  switch (a) {
    case 'public':
      return 'Public';
    case 'personal':
      return 'Personal';
    case 'corporation':
      return 'Corporation';
    case 'alliance':
      return 'Alliance';
    default:
      return a;
  }
}

String _isk(double v) {
  if (v >= 1_000_000_000) {
    return '${(v / 1_000_000_000).toStringAsFixed(2)}B ISK';
  }
  if (v >= 1_000_000) {
    return '${(v / 1_000_000).toStringAsFixed(2)}M ISK';
  }
  return '${NumberFormat('#,##0.##', 'en_US').format(v)} ISK';
}
