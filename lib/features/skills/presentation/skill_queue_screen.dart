import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../domain/skill_queue_calculator.dart';
import '../skill_providers.dart';
import 'all_skills_screen.dart';

class SkillQueueScreen extends ConsumerStatefulWidget {
  const SkillQueueScreen({super.key, required this.characterId});

  final int characterId;

  @override
  ConsumerState<SkillQueueScreen> createState() => _SkillQueueScreenState();
}

class _SkillQueueScreenState extends ConsumerState<SkillQueueScreen> {
  static const _calc = SkillQueueCalculator();
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(skillQueueProvider(widget.characterId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Queue'),
        actions: [
          IconButton(
            tooltip: 'All skills',
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AllSkillsScreen(characterId: widget.characterId),
              ),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(skillQueueProvider(widget.characterId)),
        ),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(SkillQueueData data) {
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(skillQueueProvider(widget.characterId)),
      child: data.queue.isEmpty
          ? const _EmptyState()
          : _buildList(data),
    );
  }

  Widget _buildList(SkillQueueData data) {
    final isPaused = data.queue.every((e) => e.isPaused);
    final remaining = _calc.queueTimeRemaining(data.queue, _now);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      itemCount: data.queue.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Header(
            isPaused: isPaused,
            totalRemaining: remaining,
            totalSp: data.skills.totalSp,
            unallocatedSp: data.skills.unallocatedSp,
          );
        }
        final entry = data.queue[i - 1];
        return _SkillTile(
          progress: _calc.progressOf(entry, _now),
          name: data.skillNames[entry.skillId] ?? '#${entry.skillId}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TypeDetailScreen(typeId: entry.skillId),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isPaused,
    required this.totalRemaining,
    required this.totalSp,
    required this.unallocatedSp,
  });

  final bool isPaused;
  final Duration totalRemaining;
  final int totalSp;
  final int unallocatedSp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPaused)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.pause_circle_outline, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Training is paused',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaused ? 'TIME REMAINING' : 'QUEUE EMPTIES IN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaused ? '—' : _formatDuration(totalRemaining),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        label: 'Total SP',
                        value: _formatInt(totalSp),
                      ),
                    ),
                    Expanded(
                      child: _StatBlock(
                        label: 'Unallocated',
                        value: _formatInt(unallocatedSp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.progress,
    required this.name,
    required this.onTap,
  });

  final SkillProgress progress;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = progress.entry;
    final spStart = entry.trainingStartSp ?? entry.levelStartSp;
    final percent = (progress.progressFraction * 100).clamp(0, 100);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$name ${_roman(entry.finishedLevel)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _StateBadge(state: progress.state),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progressFraction.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${_formatInt(progress.currentSp)} / ${_formatInt(entry.levelEndSp)} SP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _trailingText(progress, spStart, percent.toDouble()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _trailingText(SkillProgress p, int spStart, double percent) {
    return switch (p.state) {
      SkillTrainingState.training =>
        '${percent.toStringAsFixed(1)}% • ${_formatDuration(p.remaining)} left',
      SkillTrainingState.notYetStarted =>
        'starts in ${_formatDuration(p.entry.startDate!.difference(DateTime.now()))}',
      SkillTrainingState.completed => 'done',
      SkillTrainingState.paused => 'paused',
    };
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final SkillTrainingState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SkillTrainingState.training => ('Training', Colors.greenAccent),
      SkillTrainingState.notYetStarted => ('Queued', Colors.blueGrey),
      SkillTrainingState.completed => ('Done', Theme.of(context).hintColor),
      SkillTrainingState.paused => ('Paused', Colors.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
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
              const Icon(Icons.school_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Queue is empty',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Add skills to start training.'),
            ],
          ),
        ),
      ],
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

String _formatInt(int n) => NumberFormat('#,##0', 'en_US').format(n);

String _formatDuration(Duration d) {
  if (d.inSeconds <= 0) return '0s';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  if (days > 0) return '${days}d ${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String _roman(int level) =>
    const ['', 'I', 'II', 'III', 'IV', 'V'][level.clamp(0, 5)];
