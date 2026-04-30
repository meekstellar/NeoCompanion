import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../data/dto/planet_summary.dart';
import '../planet_providers.dart';
import 'planet_detail_screen.dart';

class PlanetaryColoniesScreen extends ConsumerWidget {
  const PlanetaryColoniesScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planetColoniesProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Planetary Colonies')),
      body: async.unwrapPrevious().when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(describeEsiError(e), textAlign: TextAlign.center),
              ),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(planetColoniesProvider(characterId).future),
              child: data.colonies.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 64),
                      Center(child: Text('No planetary colonies')),
                    ])
                  : _ColonyList(data: data, characterId: characterId),
            ),
          ),
    );
  }
}

class _ColonyList extends StatelessWidget {
  const _ColonyList({required this.data, required this.characterId});
  final PlanetColoniesData data;
  final int characterId;

  @override
  Widget build(BuildContext context) {
    final sorted = [...data.colonies]
      ..sort((a, b) {
        final sa = data.systemNames[a.solarSystemId] ?? '';
        final sb = data.systemNames[b.solarSystemId] ?? '';
        final byPlanetType = a.planetType.compareTo(b.planetType);
        return sa.compareTo(sb) != 0 ? sa.compareTo(sb) : byPlanetType;
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (_, i) =>
          _ColonyRow(colony: sorted[i], data: data, characterId: characterId),
    );
  }
}

class _ColonyRow extends StatelessWidget {
  const _ColonyRow({
    required this.colony,
    required this.data,
    required this.characterId,
  });
  final PlanetSummary colony;
  final PlanetColoniesData data;
  final int characterId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final system = data.systemNames[colony.solarSystemId] ??
        'System #${colony.solarSystemId}';
    final planetTypeId = planetTypeIdFor(colony.planetType);
    final planetTypeLabel = planetTypeLabelFor(colony.planetType);
    final lastUpdate = relativePiTime(colony.lastUpdate);

    return ListTile(
      leading: planetTypeId == null
          ? const SizedBox(width: 40, height: 40)
          : EveTypeImage(
              typeId: planetTypeId,
              size: 40,
              borderRadius: BorderRadius.circular(20),
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlanetDetailScreen(
            characterId: characterId,
            colony: colony,
            systemName: system,
          ),
        ),
      ),
      title: Text(
        '$system · $planetTypeLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Command level ${colony.upgradeLevel} · '
          '${colony.numPins} structures · '
          'updated $lastUpdate',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.hintColor),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Maps the PI planet-type slug to the corresponding inventory typeId
/// so we can pull the planet thumbnail from the EVE image server. Only
/// the `icon` variant exists for these — `render` 404s.
int? planetTypeIdFor(String type) {
  switch (type) {
    case 'temperate':
      return 11;
    case 'ice':
      return 12;
    case 'gas':
      return 13;
    case 'oceanic':
      return 2014;
    case 'lava':
      return 2015;
    case 'barren':
      return 2016;
    case 'storm':
      return 2017;
    case 'plasma':
      return 2063;
    default:
      return null;
  }
}

String planetTypeLabelFor(String type) {
  if (type.isEmpty) return 'Unknown planet';
  return '${type[0].toUpperCase()}${type.substring(1)}';
}

String relativePiTime(DateTime t) {
  final d = DateTime.now().toUtc().difference(t.toUtc());
  if (d.inDays > 1) return '${d.inDays} days ago';
  if (d.inDays == 1) return '1 day ago';
  if (d.inHours > 1) return '${d.inHours} hours ago';
  if (d.inHours == 1) return '1 hour ago';
  if (d.inMinutes > 1) return '${d.inMinutes} minutes ago';
  return 'just now';
}
