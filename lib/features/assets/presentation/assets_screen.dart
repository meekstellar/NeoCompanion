import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../asset_providers.dart';
import '../data/dto/asset_item.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assetsProvider(widget.characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
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
              ref.invalidate(assetsProvider(widget.characterId)),
          child: _build(data),
        ),
      ),
    );
  }

  Widget _build(AssetsData data) {
    final query = _filter.text.trim().toLowerCase();

    String typeName(int id) => data.typeNames[id] ?? '#$id';
    String locationName(int id) => data.locationNames[id] ?? 'Location #$id';

    final filtered = query.isEmpty
        ? data.items
        : data.items
            .where((i) => typeName(i.typeId).toLowerCase().contains(query))
            .toList();

    final byLocation = <int, List<AssetItem>>{};
    for (final item in filtered) {
      byLocation.putIfAbsent(item.locationId, () => []).add(item);
    }
    final locations = byLocation.keys.toList()
      ..sort((a, b) => locationName(a).compareTo(locationName(b)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Filter by type name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${filtered.length} of ${data.items.length} items '
                'in ${locations.length} locations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: locations.isEmpty
              ? const Center(child: Text('No matching items'))
              : ListView.builder(
                  itemCount: locations.length,
                  itemBuilder: (context, i) {
                    final loc = locations[i];
                    final items = byLocation[loc]!;
                    return ExpansionTile(
                      title: Text(locationName(loc)),
                      subtitle: Text('${items.length} items'),
                      childrenPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final it in items)
                          _AssetRow(item: it, typeName: typeName(it.typeId)),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.item, required this.typeName});

  final AssetItem item;
  final String typeName;

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity;
    final qtyText = qty > 1 ? NumberFormat('#,##0', 'en_US').format(qty) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              typeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.isBlueprintCopy)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'BPC',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            ),
          if (qtyText.isNotEmpty)
            Text(
              '×$qtyText',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
        ],
      ),
    );
  }
}
