import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../contract_providers.dart';
import '../data/dto/contract.dart';
import 'contract_detail_screen.dart';

class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Contracts')),
      body: async.unwrapPrevious().when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(describeEsiError(e), textAlign: TextAlign.center),
              ),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(contractsProvider(characterId).future),
              child: data.contracts.isEmpty
                  ? ListView(
                      // Wrap empty state in a scrollable so pull-to-refresh
                      // still works.
                      children: const [
                        SizedBox(height: 64),
                        Center(child: Text('No contracts')),
                      ],
                    )
                  : _ContractList(data: data, characterId: characterId),
            ),
          ),
    );
  }
}

class _ContractList extends StatelessWidget {
  const _ContractList({required this.data, required this.characterId});

  final ContractsData data;
  final int characterId;

  @override
  Widget build(BuildContext context) {
    // Active first, completed below; within each bucket sort by date
    // issued descending so the newest contract is on top.
    final sorted = [...data.contracts]
      ..sort((a, b) {
        final ai = _activePriority(a.status);
        final bi = _activePriority(b.status);
        if (ai != bi) return ai.compareTo(bi);
        return b.dateIssued.compareTo(a.dateIssued);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (context, i) => _ContractRow(
        contract: sorted[i],
        data: data,
        characterId: characterId,
      ),
    );
  }

  /// Lower number = nearer the top of the list. Outstanding /
  /// in-progress contracts come first; finished bucket second;
  /// cancelled / rejected at the bottom.
  static int _activePriority(String status) {
    switch (status) {
      case 'outstanding':
      case 'in_progress':
        return 0;
      case 'finished':
      case 'finished_issuer':
      case 'finished_contractor':
        return 1;
      default:
        return 2;
    }
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({
    required this.contract,
    required this.data,
    required this.characterId,
  });

  final Contract contract;
  final ContractsData data;
  final int characterId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = contract.startLocationId == null
        ? null
        : (data.locationNames[contract.startLocationId!] ?? 'Unknown');
    final end = contract.endLocationId == null
        ? null
        : (data.locationNames[contract.endLocationId!] ?? 'Unknown');
    final route = contract.isCourier && start != null && end != null
        ? '$start → $end'
        : (start ?? end ?? '');
    final issuer = data.partyNames[contract.issuerId];
    final assignee = contract.assigneeId == null || contract.assigneeId == 0
        ? null
        : data.partyNames[contract.assigneeId!];

    final title = contract.title.isNotEmpty
        ? contract.title
        : _autoTitle(contract);

    final amount = _primaryAmount(contract);

    final isFinished = _isFinished(contract.status);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: isFinished ? theme.hintColor : null,
    );

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ContractDetailScreen(
            contract: contract,
            data: data,
            characterId: characterId,
          ),
        ),
      ),
      title: Row(
        children: [
          _StatusBadge(status: contract.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          if (amount != null)
            Text(
              '${_formatIsk(amount)} ISK',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isFinished
                    ? theme.hintColor
                    : theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      // Only echo the contract type as a separate line when the
      // player wrote a real title — the auto-generated fallback
      // ("Courier (X m³)", "Item Exchange", "Auction") already
      // contains the type, and a "Courier" line under
      // "Courier (5,000 m³)" is just visual noise.
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contract.title.isNotEmpty)
              Text(
                _typeLabel(contract.type),
                style: theme.textTheme.bodySmall,
              ),
            if (route.isNotEmpty)
              Text(
                route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            if (issuer != null || assignee != null)
              Text(
                [
                  if (issuer != null) 'From $issuer',
                  if (assignee != null) 'To $assignee',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
          ],
        ),
      ),
      isThreeLine: true,
    );
  }
}

/// Pill-shaped status badge. Background colour carries the meaning at
/// a glance — primary for live contracts, green for finished, red for
/// failed / rejected, neutral for everything else.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = _badgeColor(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colour.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

bool _isFinished(String status) {
  switch (status) {
    case 'finished':
    case 'finished_issuer':
    case 'finished_contractor':
    case 'cancelled':
    case 'rejected':
    case 'failed':
    case 'deleted':
    case 'reversed':
      return true;
    default:
      return false;
  }
}

Color _badgeColor(ThemeData theme, String status) {
  switch (status) {
    case 'outstanding':
    case 'in_progress':
      return theme.colorScheme.primary;
    case 'finished':
    case 'finished_issuer':
    case 'finished_contractor':
      return Colors.green;
    case 'failed':
    case 'rejected':
      return Colors.redAccent;
    case 'cancelled':
    case 'deleted':
    case 'reversed':
    default:
      return theme.hintColor;
  }
}

String _autoTitle(Contract c) {
  switch (c.type) {
    case 'item_exchange':
      return 'Item Exchange';
    case 'auction':
      return 'Auction';
    case 'courier':
      return 'Courier (${c.volume.toStringAsFixed(0)} m³)';
    case 'loan':
      return 'Loan';
    default:
      return 'Contract #${c.contractId}';
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'item_exchange':
      return 'Item exchange';
    case 'auction':
      return 'Auction';
    case 'courier':
      return 'Courier';
    case 'loan':
      return 'Loan';
    default:
      return type;
  }
}

String _statusLabel(String status) {
  switch (status) {
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
      return status;
  }
}

double? _primaryAmount(Contract c) {
  if (c.isCourier) return c.reward > 0 ? c.reward : null;
  if (c.isAuction) return c.buyout > 0 ? c.buyout : c.price;
  if (c.price > 0) return c.price;
  if (c.reward > 0) return c.reward;
  return null;
}

String _formatIsk(double v) {
  if (v >= 1_000_000_000) {
    return '${(v / 1_000_000_000).toStringAsFixed(2)}B';
  }
  if (v >= 1_000_000) {
    return '${(v / 1_000_000).toStringAsFixed(2)}M';
  }
  if (v >= 1_000) {
    return NumberFormat('#,##0', 'en_US').format(v);
  }
  return v.toStringAsFixed(2);
}
