import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/market_order.dart';
import '../market_providers.dart';

class MarketOrdersScreen extends ConsumerWidget {
  const MarketOrdersScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketOrdersProvider(characterId));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Market orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sell'),
              Tab(text: 'Buy'),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(describeEsiError(e), textAlign: TextAlign.center),
            ),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(marketOrdersProvider(characterId)),
            child: TabBarView(
              children: [
                _OrderList(
                  orders: data.orders.where((o) => !o.isBuyOrder).toList(),
                  data: data,
                  emptyMessage: 'No active sell orders',
                ),
                _OrderList(
                  orders: data.orders.where((o) => o.isBuyOrder).toList(),
                  data: data,
                  emptyMessage: 'No active buy orders',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.data,
    required this.emptyMessage,
  });

  final List<MarketOrder> orders;
  final MarketOrdersData data;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 96),
          Center(child: Text(emptyMessage)),
        ],
      );
    }
    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (context, i) => _OrderTile(order: orders[i], data: data),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.data});
  final MarketOrder order;
  final MarketOrdersData data;

  @override
  Widget build(BuildContext context) {
    final typeName = data.typeNames[order.typeId] ?? '#${order.typeId}';
    final location =
        data.locationNames[order.locationId] ?? 'Location #${order.locationId}';
    final progress = order.volumeRemain / order.volumeTotal;
    final remainingDays = order.expiresAt.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  typeName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatIsk(order.price),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  location,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$remainingDays d',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatInt(order.volumeRemain)} / '
            '${_formatInt(order.volumeTotal)} remaining',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatIsk(double v) =>
    '${NumberFormat('#,##0.00', 'en_US').format(v)} ISK';
String _formatInt(int n) => NumberFormat('#,##0', 'en_US').format(n);
