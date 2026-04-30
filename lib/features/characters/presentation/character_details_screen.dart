import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database_providers.dart';
import '../character_providers.dart';

class CharacterDetailsScreen extends ConsumerWidget {
  const CharacterDetailsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(characterSheetProvider(characterId));
    final typesDb = ref.watch(typesDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Character Sheet')),
      body: sheet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeEsiError(e))),
        data: (data) {
          final raceName = data.publicInfo.raceId == null
              ? null
              : typesDb.lookupRace(data.publicInfo.raceId!);
          final bloodlineName = data.publicInfo.bloodlineId == null
              ? null
              : typesDb.lookupBloodline(data.publicInfo.bloodlineId!);
          final factionName = data.publicInfo.factionId == null
              ? null
              : typesDb.lookupFaction(data.publicInfo.factionId!);
          return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(characterSheetProvider(characterId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            children: [
              _Section(
                title: 'Identity',
                rows: [
                  _Row(label: 'Name', value: data.publicInfo.name),
                  _Row(
                    label: 'Security',
                    value: data.publicInfo.securityStatus.toStringAsFixed(2),
                    valueColor: _secColor(data.publicInfo.securityStatus),
                  ),
                  _Row(
                    label: 'Corporation',
                    value: data.nameOf(data.publicInfo.corporationId) ??
                        '#${data.publicInfo.corporationId}',
                  ),
                  if (data.publicInfo.allianceId != null)
                    _Row(
                      label: 'Alliance',
                      value: data.nameOf(data.publicInfo.allianceId) ??
                          '#${data.publicInfo.allianceId}',
                    ),
                  if (raceName != null) _Row(label: 'Race', value: raceName),
                  if (bloodlineName != null)
                    _Row(label: 'Bloodline', value: bloodlineName),
                  if (factionName != null)
                    _Row(label: 'Faction', value: factionName),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Location',
                rows: [
                  _Row(
                    label: 'System',
                    value: data.nameOf(data.location.solarSystemId) ??
                        '#${data.location.solarSystemId}',
                  ),
                  if (data.location.stationId != null)
                    _Row(
                      label: 'Station',
                      value: data.nameOf(data.location.stationId) ??
                          '#${data.location.stationId}',
                    ),
                  if (data.location.structureId != null)
                    _Row(
                      label: 'Structure',
                      value: '#${data.location.structureId}',
                    ),
                  _Row(label: 'Ship', value: data.ship.shipName),
                  _Row(
                    label: 'Hull',
                    value: data.nameOf(data.ship.shipTypeId) ??
                        '#${data.ship.shipTypeId}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TypeDetailScreen(typeId: data.ship.shipTypeId),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AttributesSection(characterId: characterId),
              const SizedBox(height: 16),
              _ImplantsSection(characterId: characterId),
            ],
          ),
        );
        },
      ),
    );
  }
}

class _AttributesSection extends ConsumerWidget {
  const _AttributesSection({required this.characterId});
  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(characterAttributesProvider(characterId));
    return async.when(
      loading: () => const _Section(
        title: 'Attributes',
        rows: [_Row(label: '', value: 'Loading…')],
      ),
      error: (e, _) => _Section(
        title: 'Attributes',
        rows: [_Row(label: '', value: describeEsiError(e))],
      ),
      data: (a) {
        final cooldown = a.accruedRemapCooldownDate;
        final cooldownReady =
            cooldown == null || cooldown.isBefore(DateTime.now());
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTRIBUTES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                _AttributeRow(
                  asset: 'assets/icons/attributes/Perception.png',
                  label: 'Perception',
                  value: a.perception,
                ),
                _AttributeRow(
                  asset: 'assets/icons/attributes/Intelligence.png',
                  label: 'Intelligence',
                  value: a.intelligence,
                ),
                _AttributeRow(
                  asset: 'assets/icons/attributes/Memory.png',
                  label: 'Memory',
                  value: a.memory,
                ),
                _AttributeRow(
                  asset: 'assets/icons/attributes/Willpower.png',
                  label: 'Willpower',
                  value: a.willpower,
                ),
                _AttributeRow(
                  asset: 'assets/icons/attributes/Charisma.png',
                  label: 'Charisma',
                  value: a.charisma,
                ),
                const Divider(height: 24),
                _Row(label: 'Bonus remaps', value: '${a.bonusRemaps}'),
                _Row(
                  label: 'Next remap',
                  value: cooldown == null
                      ? 'Available now'
                      : (cooldownReady
                          ? 'Available now'
                          : DateFormat('MMM d, yyyy')
                              .format(cooldown.toLocal())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.asset,
    required this.label,
    required this.value,
  });

  final String asset;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Image.asset(asset, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ImplantsSection extends ConsumerWidget {
  const _ImplantsSection({required this.characterId});
  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(characterImplantsProvider(characterId));
    final db = ref.watch(typesDatabaseProvider);
    return async.when(
      loading: () => const _Section(
        title: 'Implants',
        rows: [_Row(label: '', value: 'Loading…')],
      ),
      error: (e, _) => _Section(
        title: 'Implants',
        rows: [_Row(label: '', value: describeEsiError(e))],
      ),
      data: (ids) {
        if (ids.isEmpty) {
          return const _Section(
            title: 'Implants',
            rows: [_Row(label: '', value: 'None plugged in')],
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPLANTS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),
                for (final id in ids)
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
                              db.lookup(id) ?? '#$id',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Color _secColor(double s) {
  if (s < 0) return Colors.redAccent;
  if (s < 0.5) return Colors.amber;
  return Colors.greenAccent;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

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
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onTap != null ? colors.primary : valueColor,
                    fontWeight:
                        valueColor != null ? FontWeight.w600 : null,
                    decoration: onTap != null
                        ? TextDecoration.underline
                        : null,
                    decorationColor:
                        onTap != null ? colors.primary : null,
                  ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right,
                size: 18, color: Theme.of(context).hintColor),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}
