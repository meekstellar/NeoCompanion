import 'package:flutter/material.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';

/// Market-group-tree renderer for picker results — same shape as the
/// in-game market browser. Walks the SDE's market-group hierarchy
/// rooted at [rootMarketGroupId] (or the whole tree if null), keeping
/// only branches that contain at least one item from [matches]. Tap
/// an item to pop the picker with its type id.
class MarketGroupTree extends StatelessWidget {
  const MarketGroupTree({
    super.key,
    required this.db,
    required this.matches,
    required this.rootMarketGroupId,
    required this.autoExpand,
    required this.onPick,
    this.imageKind = EveTypeImageKind.icon,
    this.imageSize = 36,
    this.leading,
  });

  final TypesDatabase db;
  final List<TypeMatch> matches;
  final void Function(int typeId) onPick;

  /// Optional widget rendered before the tree — used by the module
  /// picker to show "Currently fitted: …" with a Remove action.
  final Widget? leading;

  /// Tree root. Null means show every visible top-level market group;
  /// non-null shows only the named subtree (e.g. 9 = "Modules",
  /// 1111 = "Rigs", 4 = "Ships", 157 = "Drones").
  final int? rootMarketGroupId;

  /// When true, every visible group renders pre-expanded. Set to true
  /// while the user is searching so the matches are visible without
  /// hunting through tiles.
  final bool autoExpand;

  final EveTypeImageKind imageKind;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    // Bucket matches by their direct market group, and build the set
    // of ancestor groups that need to render so the path from each
    // match to the root stays visible.
    final byGroup = <int?, List<TypeMatch>>{};
    final visible = <int>{};
    for (final m in matches) {
      final mg = db.typeMarketGroupId(m.typeId);
      byGroup.putIfAbsent(mg, () => []).add(m);
      var cur = mg;
      while (cur != null) {
        if (!visible.add(cur)) break;
        cur = db.marketGroupParent(cur);
      }
    }

    // Decide which groups to render under the root.
    final List<int> rootChildren;
    final List<TypeMatch> rootItems;
    if (rootMarketGroupId == null) {
      rootChildren = db
          .marketGroupChildren(null)
          .where(visible.contains)
          .toList();
      rootItems = byGroup[null] ?? const [];
    } else {
      rootChildren = db
          .marketGroupChildren(rootMarketGroupId)
          .where(visible.contains)
          .toList();
      rootItems = byGroup[rootMarketGroupId] ?? const [];
    }
    rootChildren.sort((a, b) {
      final na = (db.lookupMarketGroup(a) ?? '').toLowerCase();
      final nb = (db.lookupMarketGroup(b) ?? '').toLowerCase();
      return na.compareTo(nb);
    });

    if (rootChildren.isEmpty && rootItems.isEmpty) {
      return const Center(child: Text('No matches'));
    }

    return ListView(
      children: [
        ?leading,
        for (final m in _sortedItems(rootItems)) _itemTile(context, m),
        for (final gid in rootChildren)
          _GroupTile(
            // Re-key on autoExpand so the tile re-initialises its
            // expansion state when search toggles.
            key: ValueKey('$autoExpand-$gid'),
            db: db,
            groupId: gid,
            byGroup: byGroup,
            visible: visible,
            autoExpand: autoExpand,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
      ],
    );
  }

  Widget _itemTile(BuildContext context, TypeMatch m) {
    return ListTile(
      dense: true,
      leading: EveTypeImage(
        typeId: m.typeId,
        kind: imageKind,
        size: imageSize,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(m.name),
      onTap: () => onPick(m.typeId),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    super.key,
    required this.db,
    required this.groupId,
    required this.byGroup,
    required this.visible,
    required this.autoExpand,
    required this.imageKind,
    required this.imageSize,
    required this.onPick,
  });

  final TypesDatabase db;
  final int groupId;
  final Map<int?, List<TypeMatch>> byGroup;
  final Set<int> visible;
  final bool autoExpand;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final void Function(int typeId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = db
        .marketGroupChildren(groupId)
        .where(visible.contains)
        .toList()
      ..sort((a, b) {
        final na = (db.lookupMarketGroup(a) ?? '').toLowerCase();
        final nb = (db.lookupMarketGroup(b) ?? '').toLowerCase();
        return na.compareTo(nb);
      });
    final items = _sortedItems(byGroup[groupId] ?? const []);
    final name = db.lookupMarketGroup(groupId) ?? 'Group #$groupId';
    final totalUnder = _countMatches(groupId);

    return ExpansionTile(
      initiallyExpanded: autoExpand,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(left: 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$totalUnder',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      children: [
        for (final m in items)
          ListTile(
            dense: true,
            leading: EveTypeImage(
              typeId: m.typeId,
              kind: imageKind,
              size: imageSize,
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text(m.name),
            onTap: () => onPick(m.typeId),
          ),
        for (final cid in children)
          _GroupTile(
            key: ValueKey('$autoExpand-$cid'),
            db: db,
            groupId: cid,
            byGroup: byGroup,
            visible: visible,
            autoExpand: autoExpand,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
      ],
    );
  }

  /// Total matching items rooted at [groupId] including all
  /// descendant groups — purely for the count badge in the header.
  int _countMatches(int groupId) {
    var total = (byGroup[groupId] ?? const []).length;
    for (final c in db.marketGroupChildren(groupId)) {
      if (!visible.contains(c)) continue;
      total += _countMatches(c);
    }
    return total;
  }
}

List<TypeMatch> _sortedItems(List<TypeMatch> items) {
  final out = [...items];
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Lazy market-group browser — renders the in-game market hierarchy
/// without needing a precomputed match list. Each [ExpansionTile]
/// builds its children on first expand, so a top-level "Ship Equipment"
/// node with thousands of descendants stays cheap until the user opens
/// it. Used by pickers (e.g. the cargo picker) where the empty-query
/// state should let the player drill the full market tree.
class MarketGroupBrowser extends StatelessWidget {
  const MarketGroupBrowser({
    super.key,
    required this.db,
    required this.onPick,
    this.rootMarketGroupId,
    this.imageKind = EveTypeImageKind.icon,
    this.imageSize = 36,
  });

  final TypesDatabase db;
  final void Function(int typeId) onPick;
  final int? rootMarketGroupId;
  final EveTypeImageKind imageKind;
  final double imageSize;

  @override
  Widget build(BuildContext context) {
    final children = db.marketGroupChildren(rootMarketGroupId).toList()
      ..sort((a, b) => (db.lookupMarketGroup(a) ?? '')
          .toLowerCase()
          .compareTo((db.lookupMarketGroup(b) ?? '').toLowerCase()));
    final directTypes = rootMarketGroupId == null
        ? const <int>[]
        : db.typesInMarketGroup(rootMarketGroupId!);
    if (children.isEmpty && directTypes.isEmpty) {
      return const Center(child: Text('Empty'));
    }
    return ListView(
      children: [
        for (final gid in children)
          _BrowserNode(
            db: db,
            groupId: gid,
            depth: 0,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
        for (final t in _typesSorted(db, directTypes))
          _BrowserTypeRow(
            db: db,
            typeId: t.id,
            name: t.name,
            depth: 0,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
      ],
    );
  }
}

class _BrowserNode extends StatelessWidget {
  const _BrowserNode({
    required this.db,
    required this.groupId,
    required this.depth,
    required this.imageKind,
    required this.imageSize,
    required this.onPick,
  });

  final TypesDatabase db;
  final int groupId;
  final int depth;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final void Function(int typeId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = db.lookupMarketGroup(groupId) ?? '#$groupId';
    final total = db.marketGroupSubtreeCount(groupId);
    final indent = 16.0 + depth * 16;
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.fromLTRB(indent, 0, 16, 0),
      childrenPadding: EdgeInsets.zero,
      title: Text(name, style: theme.textTheme.titleSmall),
      trailing: Text(
        '$total',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      children: [
        _BrowserBody(
          db: db,
          groupId: groupId,
          depth: depth,
          imageKind: imageKind,
          imageSize: imageSize,
          onPick: onPick,
        ),
      ],
    );
  }
}

class _BrowserBody extends StatelessWidget {
  const _BrowserBody({
    required this.db,
    required this.groupId,
    required this.depth,
    required this.imageKind,
    required this.imageSize,
    required this.onPick,
  });

  final TypesDatabase db;
  final int groupId;
  final int depth;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final void Function(int typeId) onPick;

  @override
  Widget build(BuildContext context) {
    final subgroups = db.marketGroupChildren(groupId).toList()
      ..sort((a, b) => (db.lookupMarketGroup(a) ?? '')
          .toLowerCase()
          .compareTo((db.lookupMarketGroup(b) ?? '').toLowerCase()));
    final types = _typesSorted(db, db.typesInMarketGroup(groupId));
    return Column(
      children: [
        for (final sgId in subgroups)
          _BrowserNode(
            db: db,
            groupId: sgId,
            depth: depth + 1,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
        for (final t in types)
          _BrowserTypeRow(
            db: db,
            typeId: t.id,
            name: t.name,
            depth: depth + 1,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: onPick,
          ),
      ],
    );
  }
}

class _BrowserTypeRow extends StatelessWidget {
  const _BrowserTypeRow({
    required this.db,
    required this.typeId,
    required this.name,
    required this.depth,
    required this.imageKind,
    required this.imageSize,
    required this.onPick,
  });

  final TypesDatabase db;
  final int typeId;
  final String name;
  final int depth;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final void Function(int typeId) onPick;

  @override
  Widget build(BuildContext context) {
    final indent = 16.0 + depth * 16;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.fromLTRB(indent, 0, 16, 0),
      leading: EveTypeImage(
        typeId: typeId,
        kind: imageKind,
        size: imageSize,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(name),
      onTap: () => onPick(typeId),
    );
  }
}

List<({int id, String name})> _typesSorted(
  TypesDatabase db,
  List<int> typeIds,
) {
  final out = <({int id, String name})>[];
  for (final tid in typeIds) {
    final n = db.lookup(tid);
    if (n == null) continue;
    out.add((id: tid, name: n));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}
