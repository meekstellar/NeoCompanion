import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';

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
              autofocus: true,
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
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final m = results[i];
            final groupName =
                m.groupId == null ? null : db.lookupGroup(m.groupId!);
            return ListTile(
              leading: EveTypeImage(
                typeId: m.typeId,
                kind: EveTypeImageKind.render,
                size: 40,
                borderRadius: BorderRadius.circular(4),
              ),
              title: Text(m.name),
              subtitle: groupName == null ? null : Text(groupName),
              onTap: () => Navigator.of(context).pop<int>(m.typeId),
            );
          },
        );
      },
    );
  }
}
