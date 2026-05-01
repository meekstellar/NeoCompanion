import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import 'market_group_tree.dart';

/// Category id for Ship in CCP's SDE.
const int _shipCategoryId = 6;

/// Searchable picker over all published ships. Pops back the selected
/// type id, or null on cancel.
class ShipPickerScreen extends ConsumerStatefulWidget {
  const ShipPickerScreen({super.key});

  @override
  ConsumerState<ShipPickerScreen> createState() => _ShipPickerScreenState();
}

class _ShipPickerScreenState extends ConsumerState<ShipPickerScreen> {
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
      appBar: AppBar(title: const Text('Pick a ship')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search ships',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 200),
                    () => setState(() => _query = v));
              },
            ),
          ),
          Expanded(child: _ShipResultsList(query: _query)),
        ],
      ),
    );
  }
}

class _ShipResultsList extends ConsumerWidget {
  const _ShipResultsList({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(typesDatabaseRevisionProvider);
    final db = ref.watch(typesDatabaseProvider);
    return FutureBuilder<List<TypeMatch>>(
      future: db.searchTypesByCategory(
        categoryId: _shipCategoryId,
        query: query,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snap.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        return MarketGroupTree(
          db: db,
          matches: results,
          // Market group 4 = "Ships". The picker scopes to that
          // subtree so the user navigates Frigates → Cruisers →
          // … instead of seeing every published type at the root.
          rootMarketGroupId: 4,
          autoExpand: query.trim().isNotEmpty,
          imageKind: EveTypeImageKind.render,
          imageSize: 40,
          onPick: (id) => Navigator.of(context).pop<int>(id),
        );
      },
    );
  }
}
