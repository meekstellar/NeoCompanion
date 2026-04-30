import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/loyalty_balance.dart';
import '../loyalty_providers.dart';

class LoyaltyPointsScreen extends ConsumerWidget {
  const LoyaltyPointsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loyaltyProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Points')),
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
                  ref.refresh(loyaltyProvider(characterId).future),
              child: data.balances.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 64),
                      Center(child: Text('No loyalty points')),
                    ])
                  : _BalanceList(data: data),
            ),
          ),
    );
  }
}

class _BalanceList extends StatelessWidget {
  const _BalanceList({required this.data});
  final LoyaltyData data;

  @override
  Widget build(BuildContext context) {
    final sorted = [...data.balances]
      ..sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
    final total = sorted.fold<int>(0, (s, b) => s + b.loyaltyPoints);
    final fmt = NumberFormat('#,##0', 'en_US');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total LP',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
                Text(
                  fmt.format(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        }
        return _BalanceRow(balance: sorted[i - 1], data: data);
      },
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance, required this.data});
  final LoyaltyBalance balance;
  final LoyaltyData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat('#,##0', 'en_US');
    final corpName = data.corpNames[balance.corporationId] ??
        'Corp #${balance.corporationId}';
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl:
              'https://images.evetech.net/corporations/${balance.corporationId}/logo?size=64',
          width: 36,
          height: 36,
          placeholder: (_, _) => const SizedBox(width: 36, height: 36),
          errorWidget: (_, _, _) => const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.business_outlined, size: 20),
          ),
        ),
      ),
      title: Text(
        corpName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        fmt.format(balance.loyaltyPoints),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
