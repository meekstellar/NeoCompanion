import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types_database.dart';
import '../types_database_providers.dart';
import 'eve_type_image.dart';
import 'type_detail_screen.dart';

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
                  ? _MarketBrowser(db: db, parentId: null)
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

/// Recursively-navigable view of the in-game market hierarchy. Pass
/// `null` for the root (top-level market groups), or a market group ID
/// to show its children + types directly attached to it.
class MarketBrowserScreen extends ConsumerStatefulWidget {
  const MarketBrowserScreen({super.key, required this.parentId});
  final int parentId;

  @override
  ConsumerState<MarketBrowserScreen> createState() =>
      _MarketBrowserScreenState();
}

class _MarketBrowserScreenState extends ConsumerState<MarketBrowserScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    final title = db.lookupMarketGroup(widget.parentId) ?? 'Group';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: db,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search in this group',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: _MarketBrowser(
                db: db,
                parentId: widget.parentId,
                query: _query,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists subgroups + types directly attached to [parentId]. Used by
/// both the root entry on the item database screen (parentId = null)
/// and the dedicated [MarketBrowserScreen].
class _MarketBrowser extends StatelessWidget {
  const _MarketBrowser({
    required this.db,
    required this.parentId,
    this.query = '',
  });

  final TypesDatabase db;
  final int? parentId;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final children = db.marketGroupChildren(parentId);
    final groupRows = <(int id, String name, int totalCount)>[];
    for (final id in children) {
      final name = db.lookupMarketGroup(id) ?? '#$id';
      if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
      groupRows.add((id, name, _subtreeCount(db, id)));
    }
    groupRows.sort((a, b) => a.$2.compareTo(b.$2));

    final typeRows = <MapEntry<int, String>>[];
    if (parentId != null) {
      for (final tid in db.typesInMarketGroup(parentId!)) {
        final name = db.lookup(tid);
        if (name == null) continue;
        if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
        typeRows.add(MapEntry(tid, name));
      }
      typeRows.sort((a, b) => a.value.compareTo(b.value));
    }

    final showOtherPseudo = parentId == null && q.isEmpty;

    if (groupRows.isEmpty && typeRows.isEmpty && !showOtherPseudo) {
      return Center(
        child: Text(
          'No matches',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView.builder(
      itemCount: groupRows.length +
          typeRows.length +
          (showOtherPseudo ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < groupRows.length) {
          final g = groupRows[i];
          return ListTile(
            title: Text(g.$2),
            subtitle: Text('${g.$3} items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MarketBrowserScreen(parentId: g.$1),
              ),
            ),
          );
        }
        if (i < groupRows.length + typeRows.length) {
          final e = typeRows[i - groupRows.length];
          return _TypeRow(typeId: e.key, name: e.value);
        }
        // "Other" pseudo-entry at the root.
        return ListTile(
          title: const Text('Other'),
          subtitle: Text('${db.typesWithoutMarketGroup.length} items'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _OtherCategoriesScreen(),
            ),
          ),
        );
      },
    );
  }

  /// Total type count under [groupId] (its types + types of all
  /// descendants). Cached only implicitly via Dart Map performance.
  static int _subtreeCount(TypesDatabase db, int groupId) {
    var total = db.typesInMarketGroup(groupId).length;
    for (final child in db.marketGroupChildren(groupId)) {
      total += _subtreeCount(db, child);
    }
    return total;
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.db, required this.query});
  final TypesDatabase db;
  final String query;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = db.entries
        .where((e) => e.value.toLowerCase().contains(q))
        .toList(growable: false)
      ..sort((a, b) => a.value.compareTo(b.value));

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No matches',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, i) =>
          _TypeRow(typeId: filtered[i].key, name: filtered[i].value),
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
  const _TypeRow({required this.typeId, required this.name});
  final int typeId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
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
