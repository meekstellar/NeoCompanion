import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';

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
              autofocus: true,
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
  });

  final TypeSearcher search;
  final String query;
  final EveTypeImageKind imageKind;
  final double imageSize;

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
                kind: imageKind,
                size: imageSize,
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
