import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types_database.dart';
import '../types_database_providers.dart';
import 'eve_type_image.dart';
import 'type_detail_screen.dart';

/// Browse the in-game market hierarchy as a single inline tree.
/// Empty search renders the tree (lazy: each [ExpansionTile] only
/// builds its children on first expand). A non-empty query switches
/// to a flat list of matching types — when a player is hunting for a
/// specific name they don't want to drill the tree, they want results.
class ItemDatabaseScreen extends ConsumerStatefulWidget {
  const ItemDatabaseScreen({super.key});

  @override
  ConsumerState<ItemDatabaseScreen> createState() =>
      _ItemDatabaseScreenState();
}

class _ItemDatabaseScreenState extends ConsumerState<ItemDatabaseScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item database'),
        actions: [
          IconButton(
            tooltip: 'Reset database',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmReset(context, db),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: db,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search items',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _MarketTree(db: db)
                  : _SearchResults(db: db, query: _query),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, TypesDatabase db) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset database?'),
        content: const Text(
          'This deletes the local item database. You will need to '
          'download it again before using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await db.reset();
    navigator.pop();
  }
}

/// Top-level market tree: one tile per root market group plus an
/// "Other" entry that bridges to the orphan-types fallback.
class _MarketTree extends StatelessWidget {
  const _MarketTree({required this.db});
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final roots = db.marketGroupChildren(null).toList()
      ..sort((a, b) => (db.lookupMarketGroup(a) ?? '')
          .compareTo(db.lookupMarketGroup(b) ?? ''));
    return ListView(
      children: [
        for (final groupId in roots)
          _GroupNode(db: db, groupId: groupId, depth: 0),
        if (db.typesWithoutMarketGroup.isNotEmpty)
          ListTile(
            title: const Text('Other'),
            subtitle: Text('${db.typesWithoutMarketGroup.length} items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _OtherCategoriesScreen(),
              ),
            ),
          ),
      ],
    );
  }
}

/// One market-group node. Renders an [ExpansionTile] whose children
/// — child groups and types directly attached to this group — only
/// build when the user expands it. That keeps the initial paint cheap
/// no matter how deep the tree is.
class _GroupNode extends StatelessWidget {
  const _GroupNode({
    required this.db,
    required this.groupId,
    required this.depth,
  });

  final TypesDatabase db;
  final int groupId;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final name = db.lookupMarketGroup(groupId) ?? '#$groupId';
    final total = db.marketGroupSubtreeCount(groupId);
    final indent = 16.0 + depth * 16;
    return ExpansionTile(
      tilePadding: EdgeInsets.fromLTRB(indent, 0, 16, 0),
      childrenPadding: EdgeInsets.zero,
      title: Text(name),
      subtitle: Text('$total items'),
      children: [_ExpandedGroupBody(db: db, groupId: groupId, depth: depth)],
    );
  }
}

/// Pulled out so the (potentially expensive) children-list construction
/// only runs once the parent [ExpansionTile] expands; the tile itself
/// builds even when collapsed.
class _ExpandedGroupBody extends StatelessWidget {
  const _ExpandedGroupBody({
    required this.db,
    required this.groupId,
    required this.depth,
  });

  final TypesDatabase db;
  final int groupId;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final subgroups = db.marketGroupChildren(groupId).toList()
      ..sort((a, b) => (db.lookupMarketGroup(a) ?? '')
          .compareTo(db.lookupMarketGroup(b) ?? ''));
    final types = [
      for (final tid in db.typesInMarketGroup(groupId))
        if (db.lookup(tid) != null) (id: tid, name: db.lookup(tid)!),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        for (final sgId in subgroups)
          _GroupNode(db: db, groupId: sgId, depth: depth + 1),
        for (final t in types)
          _TypeRow(typeId: t.id, name: t.name, depth: depth + 1),
      ],
    );
  }
}

/// Flat result list, capped to keep substring scans on the 30k-entry
/// hot-cache snappy. Sorted by name; at 200 hits the user is well
/// served by adding more characters to the query.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.db, required this.query});
  final TypesDatabase db;
  final String query;

  static const int _limit = 200;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final hits = <MapEntry<int, String>>[];
    for (final e in db.entries) {
      if (e.value.toLowerCase().contains(q)) {
        hits.add(e);
        if (hits.length >= _limit + 1) break;
      }
    }
    final truncated = hits.length > _limit;
    if (truncated) hits.removeLast();
    hits.sort((a, b) => a.value.compareTo(b.value));

    if (hits.isEmpty) {
      return Center(
        child: Text('No matches',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ListView.builder(
      itemCount: hits.length + (truncated ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == hits.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Showing first $_limit matches — refine the search to see more.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          );
        }
        return _TypeRow(
          typeId: hits[i].key,
          name: hits[i].value,
          depth: 0,
        );
      },
    );
  }
}

/// Fallback browser for types that have no `market_group_id` (skills,
/// NPC entities, blueprint copies, …). Falls back to invCategories →
/// invGroups, the same shape we used before market groups.
class _OtherCategoriesScreen extends ConsumerStatefulWidget {
  const _OtherCategoriesScreen();

  @override
  ConsumerState<_OtherCategoriesScreen> createState() =>
      _OtherCategoriesScreenState();
}

class _OtherCategoriesScreenState
    extends ConsumerState<_OtherCategoriesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Other')),
      body: AnimatedBuilder(
        animation: db,
        builder: (context, _) {
          // Bucket orphan types by their inv-category.
          final byCategory = <int, int>{};
          for (final tid in db.typesWithoutMarketGroup) {
            final groupId = db.typeGroupId(tid);
            final categoryId =
                groupId == null ? null : db.groupCategoryId(groupId);
            if (categoryId == null) continue;
            byCategory[categoryId] = (byCategory[categoryId] ?? 0) + 1;
          }
          final categories = byCategory.keys.toList()
            ..sort((a, b) => (db.lookupCategory(a) ?? '')
                .compareTo(db.lookupCategory(b) ?? ''));
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? categories
              : categories
                  .where((id) => (db.lookupCategory(id) ?? '')
                      .toLowerCase()
                      .contains(q))
                  .toList(growable: false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search categories',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No matches',
                            style: Theme.of(context).textTheme.bodySmall),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final id = filtered[i];
                          final name = db.lookupCategory(id) ?? '#$id';
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('${byCategory[id]} items'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _OtherCategoryItemsScreen(
                                  categoryId: id,
                                  categoryName: name,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OtherCategoryItemsScreen extends ConsumerStatefulWidget {
  const _OtherCategoryItemsScreen({
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;

  @override
  ConsumerState<_OtherCategoryItemsScreen> createState() =>
      _OtherCategoryItemsScreenState();
}

class _OtherCategoryItemsScreenState
    extends ConsumerState<_OtherCategoryItemsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: AnimatedBuilder(
        animation: db,
        builder: (context, _) {
          final entries = <MapEntry<int, String>>[];
          for (final tid in db.typesWithoutMarketGroup) {
            final groupId = db.typeGroupId(tid);
            final categoryId =
                groupId == null ? null : db.groupCategoryId(groupId);
            if (categoryId != widget.categoryId) continue;
            final name = db.lookup(tid);
            if (name == null) continue;
            entries.add(MapEntry(tid, name));
          }
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? entries
              : entries
                  .where((e) => e.value.toLowerCase().contains(q))
                  .toList(growable: false);
          filtered.sort((a, b) => a.value.compareTo(b.value));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search items',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No matches',
                            style: Theme.of(context).textTheme.bodySmall),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _TypeRow(
                          typeId: filtered[i].key,
                          name: filtered[i].value,
                          depth: 0,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.typeId,
    required this.name,
    required this.depth,
  });
  final int typeId;
  final String name;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final indent = 16.0 + depth * 16;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.fromLTRB(indent, 0, 16, 0),
      leading: EveTypeImage(
        typeId: typeId,
        size: 32,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(name),
      trailing: Text(
        '#$typeId',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TypeDetailScreen(typeId: typeId),
        ),
      ),
    );
  }
}
