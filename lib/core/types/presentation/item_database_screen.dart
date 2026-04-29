import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../network/esi_error_message.dart';
import '../types_database.dart';
import '../types_database_providers.dart';
import '../types_database_updater.dart';

class ItemDatabaseScreen extends ConsumerStatefulWidget {
  const ItemDatabaseScreen({super.key});

  @override
  ConsumerState<ItemDatabaseScreen> createState() =>
      _ItemDatabaseScreenState();
}

class _ItemDatabaseScreenState extends ConsumerState<ItemDatabaseScreen> {
  StreamSubscription<TypesDatabaseProgress>? _sub;
  TypesDatabaseProgress? _progress;
  String? _error;
  bool _running = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _error = null;
      _progress = null;
    });
    final updater = ref.read(typesDatabaseUpdaterProvider);
    _sub?.cancel();
    _sub = updater.update().listen(
      (p) => setState(() => _progress = p),
      onError: (Object e) => setState(() {
        _error = describeEsiError(e);
        _running = false;
      }),
      onDone: () => setState(() => _running = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    return AnimatedBuilder(
      animation: db,
      builder: (context, _) => _buildScaffold(context, db),
    );
  }

  Widget _buildScaffold(BuildContext context, TypesDatabase db) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item database')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      db.isReady
                          ? '${NumberFormat('#,##0', 'en_US').format(db.count)} '
                              'types cached'
                          : 'Database is empty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      db.lastUpdatedAt == null
                          ? 'Never updated'
                          : 'Last updated ${_formatDate(db.lastUpdatedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _start,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(db.isReady ? 'Update now' : 'Download now'),
            ),
            const SizedBox(height: 16),
            if (_progress != null) _ProgressBlock(progress: _progress!),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'The database powers item names across Assets, Market, '
              'Fittings, Skills and Wallet. Updating takes a minute and '
              'fires a few hundred ESI requests, so do it on Wi-Fi when '
              "you can — it's only needed once and after major patches.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress});
  final TypesDatabaseProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${progress.phase} • ${progress.current} / ${progress.total}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.fraction.clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime d) =>
    DateFormat('MMM d, yyyy HH:mm').format(d.toLocal());
