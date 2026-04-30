import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sde_error_message.dart';
import '../types_database_providers.dart';
import '../types_database_updater.dart';

/// Blocks the app behind a non-dismissible dialog whenever the local
/// SDE needs the user's attention: missing entirely (first launch /
/// after a Reset), or behind CCP's current build.
class ItemDatabaseGate extends ConsumerWidget {
  const ItemDatabaseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);
    final freshness = ref.watch(typesDatabaseFreshnessProvider);

    return AnimatedBuilder(
      animation: db,
      builder: (context, _) {
        final state = _evaluate(isReady: db.isReady, freshness: freshness);
        if (state == null) return child;
        return Stack(
          children: [
            child,
            _BlockingDialog(state: state),
          ],
        );
      },
    );
  }

  _GateState? _evaluate({
    required bool isReady,
    required AsyncValue<bool?> freshness,
  }) {
    if (!isReady) return _GateState.empty;
    // Only act on a settled `false` — while the probe is in flight the
    // previous value is stale (e.g. right after a fresh import) and we
    // don't want to flash the popup.
    if (freshness.isLoading || freshness.isRefreshing) return null;
    if (freshness.value == false) return _GateState.outdated;
    return null;
  }
}

enum _GateState { empty, outdated }

class _BlockingDialog extends StatelessWidget {
  const _BlockingDialog({required this.state});

  final _GateState state;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: _DialogContent(state: state),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogContent extends ConsumerStatefulWidget {
  const _DialogContent({required this.state});

  final _GateState state;

  @override
  ConsumerState<_DialogContent> createState() => _DialogContentState();
}

class _DialogContentState extends ConsumerState<_DialogContent> {
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
        _error = describeSdeError(e);
        _running = false;
      }),
      onDone: () => setState(() => _running = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body, action) = switch (widget.state) {
      _GateState.empty => (
          'Database download required',
          'NeoCompanion needs to download the EVE item database before '
              'you can use the app. This takes about a minute on Wi-Fi '
              'and only has to be done once.',
          'Download',
        ),
      _GateState.outdated => (
          'Database update required',
          'CCP published a new EVE static data export. Update the local '
              'database to keep item names, regions and skills in sync.',
          'Update',
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        if (_running)
          _ProgressBlock(progress: _progress)
        else
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(_error == null ? action : 'Retry'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress});
  final TypesDatabaseProgress? progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress?.fraction.clamp(0.0, 1.0);
    final percent = fraction == null ? null : (fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              percent == null ? '' : '$percent%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
