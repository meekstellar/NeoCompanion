import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import '../data/dto/planet_layout.dart';
import '../data/dto/planet_summary.dart';
import '../planet_providers.dart';
import 'planetary_colonies_screen.dart'
    show planetTypeIdFor, planetTypeLabelFor, relativePiTime;

class PlanetDetailScreen extends ConsumerWidget {
  const PlanetDetailScreen({
    super.key,
    required this.characterId,
    required this.colony,
    required this.systemName,
  });

  final int characterId;
  final PlanetSummary colony;
  final String systemName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planetLayoutProvider(
      PlanetLayoutKey(characterId: characterId, planetId: colony.planetId),
    ));
    return Scaffold(
      appBar: AppBar(
        title: Text('$systemName · ${planetTypeLabelFor(colony.planetType)}'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(describeEsiError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (layout) => _Body(colony: colony, layout: layout),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.colony, required this.layout});

  final PlanetSummary colony;
  final PlanetLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Overview(colony: colony, layout: layout),
        const SizedBox(height: 16),
        if (_extractors(layout).isNotEmpty) ...[
          _Extractors(layout: layout, db: db),
          const SizedBox(height: 16),
        ],
        if (_factories(layout).isNotEmpty) ...[
          _Factories(layout: layout, db: db),
          const SizedBox(height: 16),
        ],
        if (_storages(layout).isNotEmpty) ...[
          _Storages(layout: layout, db: db),
          const SizedBox(height: 16),
        ],
        _Structures(layout: layout, db: db),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.colony, required this.layout});
  final PlanetSummary colony;
  final PlanetLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planetTypeId = planetTypeIdFor(colony.planetType);
    return _Card(
      title: 'Overview',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (planetTypeId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: EveTypeImage(
                typeId: planetTypeId,
                size: 64,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(theme, 'Planet type', planetTypeLabelFor(colony.planetType)),
                _row(theme, 'Command level', '${colony.upgradeLevel}'),
                _row(theme, 'Structures', '${layout.pins.length}'),
                _row(theme, 'Routes', '${layout.routes.length}'),
                _row(theme, 'Last updated', relativePiTime(colony.lastUpdate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Extractors extends StatelessWidget {
  const _Extractors({required this.layout, required this.db});
  final PlanetLayout layout;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final extractors = _extractors(layout);
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    return _Card(
      title: 'Extractors',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pin in extractors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: pin.extractor?.productTypeId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TypeDetailScreen(
                              typeId: pin.extractor!.productTypeId!,
                            ),
                          ),
                        ),
                child: Row(
                  children: [
                    if (pin.extractor?.productTypeId != null)
                      EveTypeImage(
                        typeId: pin.extractor!.productTypeId!,
                        size: 36,
                        borderRadius: BorderRadius.circular(4),
                      )
                    else
                      const SizedBox(width: 36, height: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.extractor?.productTypeId == null
                                ? 'Idle extractor'
                                : (db.lookup(pin.extractor!.productTypeId!) ??
                                    '#${pin.extractor!.productTypeId}'),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _extractorSubtitle(pin, now),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
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

String _extractorSubtitle(PlanetPin pin, DateTime now) {
  final ext = pin.extractor;
  if (ext == null) return '';
  final parts = <String>[];
  if (ext.qtyPerCycle != null && ext.cycleTime != null) {
    final perHour = (ext.qtyPerCycle! * 3600 / ext.cycleTime!).round();
    parts.add(
        '${NumberFormat('#,##0', 'en_US').format(perHour)} units/hour');
  }
  if (pin.expiryTime != null) {
    final remaining = pin.expiryTime!.difference(now);
    if (remaining.isNegative) {
      parts.add('Program expired');
    } else {
      parts.add('${_durLabel(remaining)} remaining');
    }
  }
  return parts.join(' · ');
}

class _Factories extends StatelessWidget {
  const _Factories({required this.layout, required this.db});
  final PlanetLayout layout;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final factories = _factories(layout);
    final theme = Theme.of(context);
    return _Card(
      title: 'Factories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pin in factories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  EveTypeImage(
                    typeId: pin.typeId,
                    size: 36,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          db.lookup(pin.typeId) ?? '#${pin.typeId}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pin.schematicId == null
                              ? 'No schematic loaded'
                              : 'Schematic #${pin.schematicId}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Storages extends StatelessWidget {
  const _Storages({required this.layout, required this.db});
  final PlanetLayout layout;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final storages = _storages(layout);
    final theme = Theme.of(context);
    return _Card(
      title: 'Storage & launchpads',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pin in storages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EveTypeImage(
                        typeId: pin.typeId,
                        size: 36,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          db.lookup(pin.typeId) ?? '#${pin.typeId}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (pin.contents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(48, 4, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final c in pin.contents)
                            Text(
                              '${db.lookup(c.typeId) ?? '#${c.typeId}'}'
                              ' · ${NumberFormat('#,##0', 'en_US').format(c.amount)}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.hintColor),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Structures extends StatelessWidget {
  const _Structures({required this.layout, required this.db});
  final PlanetLayout layout;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Group all pins by typeId so we end up with a compact roster
    // ("3 × Lava Basic Industry Facility, 1 × Command Center, …")
    // — easier to parse at a glance than the per-pin lists above
    // when several extractors / factories of the same kind sit on
    // the same planet.
    final byType = <int, int>{};
    for (final p in layout.pins) {
      byType[p.typeId] = (byType[p.typeId] ?? 0) + 1;
    }
    final entries = byType.entries.toList()
      ..sort((a, b) {
        final na = db.lookup(a.key) ?? '#${a.key}';
        final nb = db.lookup(b.key) ?? '#${b.key}';
        return na.compareTo(nb);
      });

    return _Card(
      title: 'All structures',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      db.lookup(e.key) ?? '#${e.key}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '×${e.value}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

List<PlanetPin> _extractors(PlanetLayout layout) =>
    layout.pins.where((p) => p.extractor != null).toList();

List<PlanetPin> _factories(PlanetLayout layout) =>
    layout.pins.where((p) => p.schematicId != null).toList();

List<PlanetPin> _storages(PlanetLayout layout) =>
    layout.pins.where((p) => p.contents.isNotEmpty).toList();

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
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

Widget _row(ThemeData theme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

String _durLabel(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}
