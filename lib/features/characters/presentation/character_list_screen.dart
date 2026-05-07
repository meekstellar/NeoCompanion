import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/token_set.dart';
import '../../../core/demo/demo_mode.dart';
import '../../../core/network/esi_error_message.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../skills/domain/skill_queue_calculator.dart';
import '../../skills/skill_providers.dart';
import '../character_providers.dart';
import 'character_sheet_screen.dart';

class CharacterListScreen extends ConsumerStatefulWidget {
  const CharacterListScreen({super.key});

  @override
  ConsumerState<CharacterListScreen> createState() =>
      _CharacterListScreenState();
}

class _CharacterListScreenState extends ConsumerState<CharacterListScreen> {
  Timer? _ticker;
  // Only the training-remaining text listens to this. Updating a
  // ValueNotifier instead of calling setState avoids rebuilding the
  // ListView and every _CharacterCard once per second.
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = ref.watch(storedCharactersProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Text(
                'Characters',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: characters.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(describeEsiError(e))),
                data: (list) {
                  if (list.isEmpty) return const _EmptyState();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _CharacterCard(
                      token: list[i],
                      tick: _now,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: kDemoMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCharacter(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Character'),
            ),
    );
  }

  Future<void> _addCharacter(BuildContext context, WidgetRef ref) async {
    final sso = ref.read(eveSsoServiceProvider);
    final wasEmpty =
        (ref.read(storedCharactersProvider).value ?? const []).isEmpty;
    try {
      final character = await sso.signIn();
      ref.read(activeCharacterIdProvider.notifier).set(character.id);
      ref.invalidate(storedCharactersProvider);
      if (wasEmpty) {
        unawaited(ref.read(notificationServiceProvider).requestPermissions());
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }
}

class _CharacterCard extends ConsumerWidget {
  const _CharacterCard({required this.token, required this.tick});

  final TokenSet token;
  final ValueListenable<DateTime> tick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(characterSheetProvider(token.characterId));
    final queue = ref.watch(skillQueueProvider(token.characterId));
    final cloneState = ref.watch(cloneStateProvider(token.characterId));

    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref
              .read(activeCharacterIdProvider.notifier)
              .set(token.characterId);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  CharacterSheetScreen(characterId: token.characterId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Portrait(
                characterId: token.characterId,
                corporationId: sheet.value?.publicInfo.corporationId,
                allianceId: sheet.value?.publicInfo.allianceId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sheet.value?.publicInfo.name ??
                                token.characterName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cloneState.value != null &&
                            cloneState.value != CloneState.unknown) ...[
                          const SizedBox(width: 8),
                          _CloneChip(state: cloneState.value!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _TrainingChip(
                      queue: queue.value,
                      skillNames: queue.value?.skillNames ?? const {},
                      tick: tick,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatChip(
                          label: 'ISK',
                          value: _formatIsk(sheet.value?.walletBalance),
                        ),
                        _StatChip(
                          label: 'SP',
                          value: _formatSp(queue.value?.skills.totalSp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 22,
                  color: Theme.of(context).hintColor.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.characterId,
    required this.corporationId,
    required this.allianceId,
  });

  final int characterId;
  final int? corporationId;
  final int? allianceId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl:
                  'https://images.evetech.net/characters/$characterId/portrait?size=128',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, _, _) => const Icon(Icons.person, size: 32),
            ),
          ),
          if (corporationId != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: _BadgeImage(
                url:
                    'https://images.evetech.net/corporations/$corporationId/logo?size=64',
              ),
            ),
          if (allianceId != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: _BadgeImage(
                url:
                    'https://images.evetech.net/alliances/$allianceId/logo?size=64',
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (_, _) => const SizedBox(width: 32, height: 32),
          errorWidget: (_, _, _) => const SizedBox(width: 32, height: 32),
        ),
      ),
    );
  }
}

class _TrainingChip extends StatelessWidget {
  const _TrainingChip({
    required this.queue,
    required this.skillNames,
    required this.tick,
  });

  final SkillQueueData? queue;
  final Map<int, String> skillNames;
  final ValueListenable<DateTime> tick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (queue == null) {
      return _Pill(
        background: colors.surfaceContainerHigh,
        child: Text('…', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ValueListenableBuilder<DateTime>(
      valueListenable: tick,
      builder: (context, now, _) {
        const calc = SkillQueueCalculator();
        final entry = queue!.queue
            .map((e) => calc.progressOf(e, now))
            .where((p) => p.state == SkillTrainingState.training)
            .firstOrNull;
        if (entry == null) {
          return _Pill(
            background: colors.surfaceContainerHigh,
            child: Text(
              'Not training',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final name =
            skillNames[entry.entry.skillId] ?? '#${entry.entry.skillId}';
        final level = _roman(entry.entry.finishedLevel);
        final remaining = _formatDuration(entry.remaining);
        return _Pill(
          background: colors.surfaceContainerHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$name $level',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                remaining,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      background: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Coloured Alpha/Omega badge — gold for Omega (paid), grey for Alpha
/// (free). Inferred from the queue's training rate via
/// [cloneStateProvider]; the unknown state is filtered out by the
/// caller so this widget always has something to render.
class _CloneChip extends StatelessWidget {
  const _CloneChip({required this.state});
  final CloneState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOmega = state == CloneState.omega;
    final color = isOmega ? const Color(0xFFD4AF37) : theme.hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOmega ? 'Ω' : 'α',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.background, required this.child});
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No characters yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a character to start tracking skills and wallet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatIsk(double? balance) {
  if (balance == null) return '—';
  return _compact(balance);
}

String _formatSp(int? sp) {
  if (sp == null) return '—';
  return _compact(sp.toDouble());
}

String _compact(double v) {
  // Floor to one decimal so the chip never overstates a balance —
  // toStringAsFixed rounds half-up, which can quietly add ~40M to a
  // 1.96B wallet (becomes "2.0B"). Truncation keeps the displayed
  // number a safe lower bound on what the character actually has.
  String floor1(double scaled) {
    final tenths = (scaled * 10).floor();
    final whole = tenths ~/ 10;
    final frac = tenths.remainder(10).abs();
    return '$whole.$frac';
  }

  if (v.abs() >= 1e9) return '${floor1(v / 1e9)}B';
  if (v.abs() >= 1e6) return '${floor1(v / 1e6)}M';
  if (v.abs() >= 1e3) return '${floor1(v / 1e3)}K';
  return NumberFormat('#,##0', 'en_US').format(v);
}

String _formatDuration(Duration d) {
  if (d.inSeconds <= 0) return '0s';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  if (days > 0) return '${days}d ${hours}h ${minutes}m ${seconds}s';
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String _roman(int level) =>
    const ['', 'I', 'II', 'III', 'IV', 'V'][level.clamp(0, 5)];
