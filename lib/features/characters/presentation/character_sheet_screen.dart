import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../skills/presentation/skill_queue_screen.dart';
import '../../wallet/presentation/wallet_journal_screen.dart';
import '../character_providers.dart';

class CharacterSheetScreen extends ConsumerWidget {
  const CharacterSheetScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(characterSheetProvider(characterId));
    return Scaffold(
      appBar: AppBar(
        title: sheet.maybeWhen(
          data: (d) => Text(d.publicInfo.name),
          orElse: () => const Text('Character'),
        ),
        actions: [
          IconButton(
            tooltip: 'Skill queue',
            icon: const Icon(Icons.school_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SkillQueueScreen(characterId: characterId),
              ),
            ),
          ),
        ],
      ),
      body: sheet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(characterSheetProvider(characterId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(characterSheetProvider(characterId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(data: data),
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              Card(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WalletJournalScreen(characterId: characterId),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'WALLET',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    letterSpacing: 1.2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Row(
                          label: 'Balance',
                          value: _formatIsk(data.walletBalance),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatIsk(double balance) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return '${formatter.format(balance)} ISK';
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final CharacterSheetData data;

  @override
  Widget build(BuildContext context) {
    final secStatus = data.publicInfo.securityStatus;
    final secColor = secStatus < 0
        ? Colors.redAccent
        : secStatus < 0.5
            ? Colors.amber
            : Colors.greenAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: data.portrait.px256,
            width: 96,
            height: 96,
            placeholder: (_, _) => const SizedBox(
              width: 96,
              height: 96,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, _, _) => const SizedBox(
              width: 96,
              height: 96,
              child: Icon(Icons.person, size: 48),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.publicInfo.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                data.nameOf(data.publicInfo.corporationId) ??
                    'Corp #${data.publicInfo.corporationId}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (data.publicInfo.allianceId != null) ...[
                const SizedBox(height: 2),
                Text(
                  data.nameOf(data.publicInfo.allianceId) ??
                      'Alliance #${data.publicInfo.allianceId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: secColor),
                  const SizedBox(width: 4),
                  Text(
                    secStatus.toStringAsFixed(2),
                    style: TextStyle(color: secColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
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
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(describeEsiError(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
