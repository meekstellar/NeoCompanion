import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../../../core/types/types_database_providers.dart';
import '../data/dto/industry_job.dart';
import '../industry_providers.dart';

class IndustryJobsScreen extends ConsumerWidget {
  const IndustryJobsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(industryJobsProvider(characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('Industry Jobs')),
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
                  ref.refresh(industryJobsProvider(characterId).future),
              child: data.jobs.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 64),
                      Center(child: Text('No industry jobs')),
                    ])
                  : _JobList(data: data),
            ),
          ),
    );
  }
}

class _JobList extends ConsumerWidget {
  const _JobList({required this.data});

  final IndustryJobsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Active and ready jobs first (sorted by end date — soonest to
    // finish on top), then everything else by completion date desc.
    final sorted = [...data.jobs]
      ..sort((a, b) {
        final ai = _activePriority(a);
        final bi = _activePriority(b);
        if (ai != bi) return ai.compareTo(bi);
        if (ai == 0) return a.endDate.compareTo(b.endDate);
        return (b.completedDate ?? b.endDate)
            .compareTo(a.completedDate ?? a.endDate);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 0),
      itemBuilder: (_, i) => _JobRow(job: sorted[i], data: data),
    );
  }

  static int _activePriority(IndustryJob j) {
    switch (j.status) {
      case 'active':
      case 'paused':
      case 'ready':
        return 0;
      default:
        return 1;
    }
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job, required this.data});
  final IndustryJob job;
  final IndustryJobsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(typesDatabaseProvider);
    final outputTypeId = job.productTypeId ?? job.blueprintTypeId;
    final outputName = db.lookup(outputTypeId) ?? '#$outputTypeId';
    final activity = _activityLabel(job.activityId);
    final location = data.locationNames[job.locationId] ?? 'Unknown';
    final isReady = job.isReady;
    final isActive = job.isActive;
    final isCompleted =
        job.status == 'delivered' || job.status == 'cancelled' ||
            job.status == 'reverted';
    final dim = isCompleted;

    return ListTile(
      leading: EveTypeImage(
        typeId: outputTypeId,
        size: 40,
        borderRadius: BorderRadius.circular(4),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TypeDetailScreen(typeId: outputTypeId),
        ),
      ),
      title: Row(
        children: [
          _StatusBadge(status: job.status, isReady: isReady),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              outputName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: dim ? theme.hintColor : null,
              ),
            ),
          ),
          Text(
            '×${NumberFormat('#,##0', 'en_US').format(job.runs)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: dim ? theme.hintColor : null,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity,
              style: theme.textTheme.bodySmall,
            ),
            if (isActive)
              _ProgressLine(start: job.startDate, end: job.endDate)
            else if (isReady)
              Text(
                'Ready to deliver',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.green),
              ),
            Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
      isThreeLine: true,
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().toUtc();
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final fraction =
        total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0).toDouble();
    final remaining = end.difference(now);
    final remainingLabel = remaining.isNegative
        ? 'Finishing…'
        : '${_formatDuration(remaining)} remaining';
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            remainingLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isReady});
  final String status;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, colour) = _statusVisual(theme, status, isReady);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colour.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

(String, Color) _statusVisual(
    ThemeData theme, String status, bool isReady) {
  if (isReady) return ('Ready', Colors.green);
  switch (status) {
    case 'active':
      return ('Active', theme.colorScheme.primary);
    case 'paused':
      return ('Paused', Colors.orange);
    case 'delivered':
      return ('Delivered', theme.hintColor);
    case 'cancelled':
      return ('Cancelled', theme.hintColor);
    case 'reverted':
      return ('Reverted', Colors.redAccent);
    default:
      return (status, theme.hintColor);
  }
}

String _activityLabel(int activityId) {
  switch (activityId) {
    case 1:
      return 'Manufacturing';
    case 3:
      return 'Time efficiency research';
    case 4:
      return 'Material efficiency research';
    case 5:
      return 'Copying';
    case 7:
      return 'Reverse engineering';
    case 8:
      return 'Invention';
    case 9:
      return 'Reactions';
    default:
      return 'Activity #$activityId';
  }
}

String _formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${mins}m';
  if (mins > 0) return '${mins}m';
  return '${d.inSeconds}s';
}
