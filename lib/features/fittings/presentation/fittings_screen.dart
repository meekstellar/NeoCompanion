import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database_providers.dart';
import '../data/dto/fitting.dart';
import '../data/dto/local_fitting.dart';
import '../fitting_providers.dart';
import '../local_fitting_providers.dart';
import 'eft_import_screen.dart';
import 'fitting_detail_screen.dart';
import 'local_fitting_detail_screen.dart';
import 'ship_picker_screen.dart';

class FittingsScreen extends ConsumerWidget {
  const FittingsScreen({super.key, required this.characterId});

  final int characterId;

  Future<void> _newLocalFitting(BuildContext context, WidgetRef ref) async {
    final shipTypeId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const ShipPickerScreen()),
    );
    if (shipTypeId == null) return;
    final typesDb = ref.read(typesDatabaseProvider);
    final shipName = typesDb.lookup(shipTypeId) ?? 'Ship #$shipTypeId';
    final id = await ref.read(localFittingRepositoryProvider).create(
          name: shipName,
          description: '',
          shipTypeId: shipTypeId,
        );
    ref.read(localFittingsRevisionProvider.notifier).bump();
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LocalFittingDetailScreen(
          localId: id,
          characterId: characterId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esi = ref.watch(fittingsProvider(characterId));
    final local = ref.watch(localFittingsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fittings'),
        actions: [
          IconButton(
            tooltip: 'Import from EFT',
            icon: const Icon(Icons.content_paste_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EftImportScreen(characterId: characterId),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New fitting',
        onPressed: () => _newLocalFitting(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fittingsProvider(characterId));
          ref.read(localFittingsRevisionProvider.notifier).bump();
        },
        child: _Body(
          characterId: characterId,
          esi: esi,
          local: local,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.characterId,
    required this.esi,
    required this.local,
  });

  final int characterId;
  final AsyncValue<FittingsData> esi;
  final AsyncValue<List<LocalFitting>> local;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localList = local.asData?.value ?? const <LocalFitting>[];
    final esiData = esi.asData?.value;
    final esiList = esiData?.fittings ?? const <Fitting>[];
    final esiNames = esiData?.typeNames ?? const <int, String>{};
    final typesDb = ref.watch(typesDatabaseProvider);

    if (esi.isLoading && esiData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (esi.hasError && esiData == null && localList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(describeEsiError(esi.error!),
              textAlign: TextAlign.center),
        ),
      );
    }

    if (localList.isEmpty && esiList.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      children: [
        if (localList.isNotEmpty) ...[
          const _SectionHeader(title: 'Local'),
          for (final f in localList)
            _LocalFittingTile(
              fitting: f,
              shipName: typesDb.lookup(f.shipTypeId) ?? '#${f.shipTypeId}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalFittingDetailScreen(
                    localId: f.id,
                    characterId: characterId,
                  ),
                ),
              ),
            ),
          const Divider(height: 0),
        ],
        if (esiList.isNotEmpty) ...[
          if (localList.isNotEmpty)
            const _SectionHeader(title: 'Synced from EVE'),
          for (final f in esiList)
            _EsiFittingTile(
              fitting: f,
              shipName: esiNames[f.shipTypeId] ?? '#${f.shipTypeId}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FittingDetailScreen(
                    characterId: characterId,
                    fittingId: f.fittingId,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _LocalFittingTile extends StatelessWidget {
  const _LocalFittingTile({
    required this.fitting,
    required this.shipName,
    required this.onTap,
  });

  final LocalFitting fitting;
  final String shipName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: EveTypeImage(
        typeId: fitting.shipTypeId,
        kind: EveTypeImageKind.render,
        size: 48,
        borderRadius: BorderRadius.circular(4),
      ),
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

class _EsiFittingTile extends StatelessWidget {
  const _EsiFittingTile({
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
      leading: EveTypeImage(
        typeId: fitting.shipTypeId,
        kind: EveTypeImageKind.render,
        size: 48,
        borderRadius: BorderRadius.circular(4),
      ),
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
                'Tap + to start a new fit, or save fittings in-game.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
