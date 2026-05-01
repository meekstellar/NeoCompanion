import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import 'market_group_tree.dart';

/// Function that, given a query string, produces a list of matching
/// types from the SDE. Each picker variant binds its own query
/// (effect-based, category-based, …).
typedef TypeSearcher = Future<List<TypeMatch>> Function(
  TypesDatabase db,
  String query,
);

/// Generic searchable picker. Pops back the selected type id, or null
/// on cancel. Specialised pickers (modules, ships, drones, …) configure
/// it with their own [search] and visual options.
class TypePickerScreen extends ConsumerStatefulWidget {
  const TypePickerScreen({
    super.key,
    required this.title,
    required this.search,
    this.hintText = 'Search',
    this.imageKind = EveTypeImageKind.icon,
    this.imageSize = 36,
    this.emptyQueryHint,
    this.rootMarketGroupId,
  });

  final String title;
  final TypeSearcher search;
  final String hintText;
  final EveTypeImageKind imageKind;
  final double imageSize;

  /// Shown instead of running the search when the query is empty. Set
  /// for pickers (like cargo) where dumping every published type is
  /// pointless and wasteful.
  final String? emptyQueryHint;

  /// When set, results render as a market-group tree rooted at this
  /// id (the in-game market browser layout). Null falls back to a
  /// flat group-by-group list — used by the cargo picker where the
  /// user is name-searching arbitrary items.
  final int? rootMarketGroupId;

  @override
  ConsumerState<TypePickerScreen> createState() => _TypePickerScreenState();
}

class _TypePickerScreenState extends ConsumerState<TypePickerScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.hintText,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 200),
                    () => setState(() => _query = v));
              },
            ),
          ),
          Expanded(
            child: widget.emptyQueryHint != null && _query.trim().isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.emptyQueryHint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  )
                : _Results(
                    search: widget.search,
                    query: _query,
                    imageKind: widget.imageKind,
                    imageSize: widget.imageSize,
                    rootMarketGroupId: widget.rootMarketGroupId,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.search,
    required this.query,
    required this.imageKind,
    required this.imageSize,
    required this.rootMarketGroupId,
  });

  final TypeSearcher search;
  final String query;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final int? rootMarketGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(typesDatabaseRevisionProvider);
    final db = ref.watch(typesDatabaseProvider);
    return FutureBuilder<List<TypeMatch>>(
      future: search(db, query),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snap.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        void pop(int id) => Navigator.of(context).pop<int>(id);
        if (rootMarketGroupId != null) {
          return MarketGroupTree(
            db: db,
            matches: results,
            rootMarketGroupId: rootMarketGroupId,
            autoExpand: query.trim().isNotEmpty,
            imageKind: imageKind,
            imageSize: imageSize,
            onPick: pop,
          );
        }
        return GroupedTypeResults(
          results: results,
          autoExpand: query.trim().isNotEmpty,
          imageKind: imageKind,
          imageSize: imageSize,
          onPick: pop,
        );
      },
    );
  }
}

/// Renders [results] grouped by `groupId`, with one [ExpansionTile]
/// per group (collapsed by default, optionally auto-expanded). Inside
/// each group the items are a flat list. Public so the module picker
/// (which has its own loading state for ship attributes) can reuse
/// the same look without copy-pasting the grouping logic.
class GroupedTypeResults extends ConsumerWidget {
  const GroupedTypeResults({
    super.key,
    required this.results,
    required this.autoExpand,
    required this.onPick,
    this.imageKind = EveTypeImageKind.icon,
    this.imageSize = 36,
  });

  final List<TypeMatch> results;
  final bool autoExpand;
  final void Function(int typeId) onPick;
  final EveTypeImageKind imageKind;
  final double imageSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);

    final byGroup = <int?, List<TypeMatch>>{};
    for (final m in results) {
      byGroup.putIfAbsent(m.groupId, () => []).add(m);
    }
    final groupIds = byGroup.keys.toList()
      ..sort((a, b) {
        final na = a == null ? 'Other' : (db.lookupGroup(a) ?? 'Other');
        final nb = b == null ? 'Other' : (db.lookupGroup(b) ?? 'Other');
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });

    return ListView.builder(
      itemCount: groupIds.length,
      itemBuilder: (context, i) {
        final gid = groupIds[i];
        final items = byGroup[gid]!;
        final name = gid == null ? 'Other' : (db.lookupGroup(gid) ?? 'Other');
        return _GroupSection(
          // Key on (autoExpand, gid) so the tile re-initialises its
          // expansion state whenever the query toggles between empty
          // and non-empty.
          key: ValueKey('$autoExpand-$gid'),
          name: name,
          items: items,
          initiallyExpanded: autoExpand,
          imageKind: imageKind,
          imageSize: imageSize,
          onPick: onPick,
        );
      },
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    super.key,
    required this.name,
    required this.items,
    required this.initiallyExpanded,
    required this.imageKind,
    required this.imageSize,
    required this.onPick,
  });

  final String name;
  final List<TypeMatch> items;
  final bool initiallyExpanded;
  final EveTypeImageKind imageKind;
  final double imageSize;
  final void Function(int typeId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
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
            '${items.length}',
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
      ],
    );
  }
}
