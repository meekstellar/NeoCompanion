import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../character_providers.dart';

class CharacterDetailsScreen extends ConsumerWidget {
  const CharacterDetailsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(characterSheetProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Character Sheet')),
      body: sheet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeEsiError(e))),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(characterSheetProvider(characterId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
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
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Ship',
                rows: [
                  _Row(label: 'Name', value: data.ship.shipName),
                  _Row(
                    label: 'Type',
                    value: data.nameOf(data.ship.shipTypeId) ??
                        '#${data.ship.shipTypeId}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    color: valueColor,
                    fontWeight:
                        valueColor != null ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
