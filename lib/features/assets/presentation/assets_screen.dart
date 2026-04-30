import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../asset_node.dart';
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
    // unwrapPrevious() collapses "loading with stale data" / "error with
    // stale data" back into a `data` state — so a pull-to-refresh keeps
    // the list on screen instead of flashing the spinner.
    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
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
                  ref.refresh(assetsProvider(widget.characterId).future),
              child: _build(data),
            ),
          ),
    );
  }

  Widget _build(AssetsData data) {
    final query = _filter.text.trim().toLowerCase();
    final view = _AssetsView(data: data, query: query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Filter by type or custom name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                '${view.matchedItemCount} of ${data.items.length} items '
                'in ${view.locationCount} locations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: view.locationCount == 0
              ? const Center(child: Text('No matching items'))
              : ListView.builder(
                  itemCount: view.sortedLocations.length,
                  itemBuilder: (context, i) {
                    final locationId = view.sortedLocations[i];
                    final children = view.filteredRoots[locationId]!;
                    final total = children.fold<int>(
                        0, (s, n) => s + 1 + n.totalDescendants);
                    return ExpansionTile(
                      title: Text(view.nameOf(locationId)),
                      subtitle: Text('$total items'),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(0, 0, 0, 4),
                      children: [
                        for (final node in children)
                          view.buildNode(node, depth: 0),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Pre-computes everything the screen needs from [AssetsData] for a
/// particular search query: the filtered tree, the sorted list of outer
/// locations, total matched item count. Keeps the build method
/// declarative.
class _AssetsView {
  _AssetsView({required this.data, required this.query})
      : filteredRoots = _filterTree(data.tree.rootsByLocation, data, query) {
    sortedLocations = filteredRoots.keys.toList()
      ..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    matchedItemCount = filteredRoots.values
        .expand((nodes) => nodes)
        .fold<int>(0, (s, n) => s + 1 + n.totalDescendants);
  }

  final AssetsData data;
  final String query;
  final Map<int, List<AssetNode>> filteredRoots;
  late final List<int> sortedLocations;
  late final int matchedItemCount;

  int get locationCount => sortedLocations.length;

  String typeName(int id) => data.typeNames[id] ?? '#$id';
  String? customName(int itemId) => data.customNames[itemId];
  String nameOf(int id) => data.locationNames[id] ?? 'Unknown';

  String _displayNameOf(AssetNode node) =>
      customName(node.item.itemId) ?? typeName(node.item.typeId);

  /// Builds the recursive subtree under one node. Leaves render as a
  /// row, containers as an [ExpansionTile] with the same builder applied
  /// to children.
  Widget buildNode(AssetNode node, {required int depth}) {
    final children = node.children;
    if (children.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16.0 + depth * 16, 0, 16, 0),
        child: _AssetRow(
          item: node.item,
          typeName: typeName(node.item.typeId),
          customName: customName(node.item.itemId),
        ),
      );
    }
    final sortedChildren = [...children]
      ..sort((a, b) => _displayNameOf(a).compareTo(_displayNameOf(b)));
    final hasCustom = customName(node.item.itemId) != null;
    final tName = typeName(node.item.typeId);
    final subtitle = hasCustom
        ? '$tName · ${node.totalDescendants} items'
        : '${node.totalDescendants} items';
    return ExpansionTile(
      tilePadding: EdgeInsets.fromLTRB(16.0 + depth * 16, 0, 16, 0),
      childrenPadding: EdgeInsets.zero,
      title: Row(
        children: [
          EveTypeImage(
            typeId: node.item.typeId,
            size: 28,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _displayNameOf(node),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 38),
        child: Text(subtitle),
      ),
      children: [
        for (final c in sortedChildren) buildNode(c, depth: depth + 1),
      ],
    );
  }

  /// Filters the whole roots-by-location map. Locations that end up with
  /// zero matching nodes are dropped entirely.
  static Map<int, List<AssetNode>> _filterTree(
    Map<int, List<AssetNode>> roots,
    AssetsData data,
    String query,
  ) {
    if (query.isEmpty) return roots;
    final out = <int, List<AssetNode>>{};
    roots.forEach((locationId, nodes) {
      final kept = <AssetNode>[];
      for (final n in nodes) {
        final f = _filterNode(n, data, query);
        if (f != null) kept.add(f);
      }
      if (kept.isNotEmpty) out[locationId] = kept;
    });
    return out;
  }

  /// Returns the (possibly pruned) version of [node] when it or any of
  /// its descendants matches. A node that itself matches is returned
  /// with **all** its descendants attached (so the user can see what's
  /// inside the matching container); a node that only contains matching
  /// descendants is returned with only those descendants kept.
  static AssetNode? _filterNode(
    AssetNode node,
    AssetsData data,
    String query,
  ) {
    bool matches(AssetNode n) {
      final type = data.typeNames[n.item.typeId];
      if (type != null && type.toLowerCase().contains(query)) return true;
      final custom = data.customNames[n.item.itemId];
      return custom != null && custom.toLowerCase().contains(query);
    }

    if (matches(node)) return node;
    final keptChildren = <AssetNode>[];
    for (final c in node.children) {
      final f = _filterNode(c, data, query);
      if (f != null) keptChildren.add(f);
    }
    if (keptChildren.isEmpty) return null;
    return AssetNode(node.item, children: keptChildren);
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.item,
    required this.typeName,
    this.customName,
  });

  final AssetItem item;
  final String typeName;
  final String? customName;

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity;
    final qtyText = qty > 1 ? NumberFormat('#,##0', 'en_US').format(qty) : '';
    final theme = Theme.of(context);
    final hasCustom = customName != null;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasCustom ? customName! : typeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasCustom)
                    Text(
                      typeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                ],
              ),
            ),
            if (item.isBlueprintCopy)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'BPC',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                ),
              ),
            if (qtyText.isNotEmpty)
              Text(
                '×$qtyText',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
          ],
        ),
      ),
    );
  }
}
