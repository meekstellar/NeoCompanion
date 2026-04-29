import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/fitting.dart';
import '../fitting_providers.dart';
import 'fitting_detail_screen.dart';

class FittingsScreen extends ConsumerWidget {
  const FittingsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fittingsProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Fittings')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(describeEsiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(fittingsProvider(characterId)),
          child: data.fittings.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  itemCount: data.fittings.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final f = data.fittings[i];
                    return _FittingTile(
                      fitting: f,
                      shipName: data.typeNames[f.shipTypeId] ??
                          '#${f.shipTypeId}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FittingDetailScreen(
                            characterId: characterId,
                            fittingId: f.fittingId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _FittingTile extends StatelessWidget {
  const _FittingTile({
    required this.fitting,
    required this.shipName,
    required this.onTap,
  });

  final Fitting fitting;
  final String shipName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(fitting.name),
      subtitle: Text(
        '$shipName • ${fitting.items.length} modules',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 96),
        Center(
          child: Column(
            children: [
              const Icon(Icons.layers_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'No fittings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Save fittings in-game to see them here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
