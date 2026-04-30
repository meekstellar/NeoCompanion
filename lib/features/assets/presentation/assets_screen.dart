import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
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
    String locationName(int id) => data.locationNames[id] ?? 'Unknown';

    final filtered = query.isEmpty
        ? data.items
        : data.items
            .where((i) => typeName(i.typeId).toLowerCase().contains(query))
            .toList();

    // Group by outermost station/system; within each, sub-group by
    // direct locationId so items inside our ships/containers cluster
    // under their container.
    final byOuter = <int, Map<int, List<AssetItem>>>{};
    for (final item in filtered) {
      final outer = data.outerLocation[item.locationId] ?? item.locationId;
      final inner = byOuter.putIfAbsent(outer, () => <int, List<AssetItem>>{});
      inner.putIfAbsent(item.locationId, () => []).add(item);
    }
    final outerLocations = byOuter.keys.toList()
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
                'in ${outerLocations.length} locations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: outerLocations.isEmpty
              ? const Center(child: Text('No matching items'))
              : ListView.builder(
                  itemCount: outerLocations.length,
                  itemBuilder: (context, i) {
                    final outer = outerLocations[i];
                    final groups = byOuter[outer]!;
                    final outerCount =
                        groups.values.fold<int>(0, (s, l) => s + l.length);
                    return ExpansionTile(
                      title: Text(locationName(outer)),
                      subtitle: Text('$outerCount items'),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(0, 0, 0, 4),
                      children: _buildInner(
                        outer: outer,
                        groups: groups,
                        typeName: typeName,
                        locationName: locationName,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Inside one outer location:
  ///   * loose items at the station/system itself
  ///   * one nested ExpansionTile per ship/container we own there.
  List<Widget> _buildInner({
    required int outer,
    required Map<int, List<AssetItem>> groups,
    required String Function(int) typeName,
    required String Function(int) locationName,
  }) {
    final loose = groups[outer] ?? const <AssetItem>[];
    final containerIds = groups.keys.where((k) => k != outer).toList()
      ..sort((a, b) => locationName(a).compareTo(locationName(b)));

    return [
      for (final it in loose)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _AssetRow(item: it, typeName: typeName(it.typeId)),
        ),
      for (final cid in containerIds)
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(locationName(cid)),
          subtitle: Text('${groups[cid]!.length} items'),
          childrenPadding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
          children: [
            for (final it in groups[cid]!)
              _AssetRow(item: it, typeName: typeName(it.typeId)),
          ],
        ),
    ];
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TypeDetailScreen(typeId: item.typeId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            EveTypeImage(
              typeId: item.typeId,
              size: 32,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(width: 12),
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
      ),
    );
  }
}
