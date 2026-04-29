import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types_database.dart';
import '../types_database_providers.dart';

class ItemDatabaseScreen extends ConsumerStatefulWidget {
  const ItemDatabaseScreen({super.key});

  @override
  ConsumerState<ItemDatabaseScreen> createState() =>
      _ItemDatabaseScreenState();
}

class _ItemDatabaseScreenState extends ConsumerState<ItemDatabaseScreen> {
  static const int _pageSize = 100;

  String _query = '';
  int _visible = _pageSize;

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _visible = _pageSize;
    });
  }

  void _showMore() {
    setState(() => _visible += _pageSize);
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
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: _ItemList(
                db: db,
                query: _query,
                visible: _visible,
                onShowMore: _showMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.db,
    required this.query,
    required this.visible,
    required this.onShowMore,
  });

  final TypesDatabase db;
  final String query;
  final int visible;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? db.entries.toList(growable: false)
        : db.entries
            .where((e) => e.value.toLowerCase().contains(q))
            .toList(growable: false);
    filtered.sort((a, b) => a.value.compareTo(b.value));

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No matches',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final shown = visible.clamp(0, filtered.length);
    final hasMore = shown < filtered.length;

    return ListView.builder(
      itemCount: shown + (hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == shown) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: OutlinedButton(
              onPressed: onShowMore,
              child: Text(
                'Show more (${filtered.length - shown} left)',
              ),
            ),
          );
        }
        final e = filtered[i];
        return ListTile(
          dense: true,
          title: Text(e.value),
          trailing: Text(
            '#${e.key}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
