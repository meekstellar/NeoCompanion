import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database_providers.dart';
import '../clones_providers.dart';
import '../data/dto/clones_data.dart';

class JumpClonesScreen extends ConsumerWidget {
  const JumpClonesScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jumpClonesProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Jump Clones')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(describeEsiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (view) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(jumpClonesProvider(characterId)),
          child: _build(context, ref, view),
        ),
      ),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, ClonesView view) {
    final db = ref.watch(typesDatabaseProvider);
    final data = view.data;

    String locationName(int id) => view.locationNames[id] ?? 'Unknown';

    final cards = <Widget>[];
    if (data.homeLocation != null) {
      cards.add(_HomeStation(
        location: data.homeLocation!,
        name: locationName(data.homeLocation!.locationId),
      ));
      cards.add(const SizedBox(height: 16));
    }
    if (data.lastCloneJumpDate != null) {
      cards.add(_CooldownLine(date: data.lastCloneJumpDate!));
      cards.add(const SizedBox(height: 16));
    }
    if (data.jumpClones.isEmpty) {
      cards.add(const _EmptyClones());
    } else {
      for (var i = 0; i < data.jumpClones.length; i++) {
        if (i > 0) cards.add(const SizedBox(height: 12));
        final c = data.jumpClones[i];
        cards.add(_CloneCard(
          clone: c,
          locationName: locationName(c.location.locationId),
          implantNames: {
            for (final id in c.implants)
              id: db.lookup(id) ?? '#$id',
          },
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      children: cards,
    );
  }
}

class _HomeStation extends StatelessWidget {
  const _HomeStation({required this.location, required this.name});
  final CloneLocation location;
  final String name;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Home station',
      child: Row(
        children: [
          const Icon(Icons.home_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CooldownLine extends StatelessWidget {
  const _CooldownLine({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = date.add(const Duration(hours: 24));
    final ready = next.isBefore(now);
    final formatted = DateFormat('MMM d, HH:mm').format(date.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.timer_outlined,
              color: ready ? Colors.greenAccent : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'Jump clone ready' : 'Last jump',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? 'Last jumped $formatted'
                        : 'Next jump available '
                            '${DateFormat('MMM d, HH:mm').format(next.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloneCard extends StatelessWidget {
  const _CloneCard({
    required this.clone,
    required this.locationName,
    required this.implantNames,
  });

  final JumpClone clone;
  final String locationName;
  final Map<int, String> implantNames;

  @override
  Widget build(BuildContext context) {
    final title = (clone.name == null || clone.name!.trim().isEmpty)
        ? 'Jump clone'
        : clone.name!;

    return _Section(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clone.implants.isEmpty)
            Text(
              'No implants',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            )
          else
            for (final id in clone.implants)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TypeDetailScreen(typeId: id),
                    ),
                  ),
                  child: Row(
                    children: [
                      EveTypeImage(
                        typeId: id,
                        size: 28,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          implantNames[id] ?? '#$id',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyClones extends StatelessWidget {
  const _EmptyClones();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.copy_all_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No jump clones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
