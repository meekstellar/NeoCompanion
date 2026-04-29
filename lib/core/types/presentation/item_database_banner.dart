import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/connectivity_providers.dart';
import '../types_database.dart';
import '../types_database_providers.dart';
import 'item_database_screen.dart';

/// Surfaces a banner above [child] when the local type-name database
/// needs the user's attention:
///   * empty → blocking, no item names will resolve
///   * server reports newer data → suggested update
///
/// Hidden while offline (we can't update anyway), while the freshness
/// probe is in flight, or when CCP returned 304 (the DB matches
/// upstream).
class ItemDatabaseBanner extends ConsumerWidget {
  const ItemDatabaseBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);
    ref.watch(typesDatabaseRevisionProvider);
    final online = ref.watch(connectivityStreamProvider).value ?? true;
    final freshness = ref.watch(typesDatabaseFreshnessProvider);

    final state = _evaluate(db: db, freshness: freshness);
    final visible = online && state != null;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: visible
              ? _Banner(state: state)
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }

  _State? _evaluate({
    required TypesDatabase db,
    required AsyncValue<bool?> freshness,
  }) {
    if (!db.isReady) return _State.empty;
    final fresh = freshness.value;
    if (fresh == false) return _State.outdated;
    return null;
  }
}

enum _State { empty, outdated }

class _Banner extends StatelessWidget {
  const _Banner({required this.state});
  final _State state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, label, button) = switch (state) {
      _State.empty => (
          Icons.cloud_download_outlined,
          'Item names need to be downloaded.',
          'Download',
        ),
      _State.outdated => (
          Icons.update,
          'New types are available — update the item database.',
          'Update',
        ),
    };

    return Material(
      color: colors.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ItemDatabaseScreen(),
                  ),
                ),
                child: Text(button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
