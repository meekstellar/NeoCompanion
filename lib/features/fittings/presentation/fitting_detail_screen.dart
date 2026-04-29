import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/fitting.dart';
import '../domain/eft_format.dart';
import '../domain/slot_grouping.dart';
import '../fitting_providers.dart';

class FittingDetailScreen extends ConsumerWidget {
  const FittingDetailScreen({
    super.key,
    required this.characterId,
    required this.fittingId,
  });

  final int characterId;
  final int fittingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fittingsProvider(characterId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (data) {
        final fitting =
            data.fittings.where((f) => f.fittingId == fittingId).firstOrNull;
        if (fitting == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Fitting')),
            body: const Center(child: Text('Fitting not found')),
          );
        }
        return _FittingDetailView(
          fitting: fitting,
          typeNames: data.typeNames,
        );
      },
    );
  }
}

class _FittingDetailView extends StatelessWidget {
  const _FittingDetailView({required this.fitting, required this.typeNames});

  final Fitting fitting;
  final Map<int, String> typeNames;

  String _name(int id) => typeNames[id] ?? '#$id';

  @override
  Widget build(BuildContext context) {
    final groups = groupBySlot(fitting.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(fitting.name),
        actions: [
          IconButton(
            tooltip: 'Copy as EFT',
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () async {
              final eft = exportEft(fitting, typeNames);
              await Clipboard.setData(ClipboardData(text: eft));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied as EFT')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHIP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _name(fitting.shipTypeId),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (fitting.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      fitting.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...groups.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SlotSection(
                title: e.key.title,
                items: e.value,
                resolveName: _name,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.title,
    required this.items,
    required this.resolveName,
  });

  final String title;
  final List<FittingItem> items;
  final String Function(int) resolveName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        resolveName(it.typeId),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (it.quantity > 1)
                      Text(
                        '×${it.quantity}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
