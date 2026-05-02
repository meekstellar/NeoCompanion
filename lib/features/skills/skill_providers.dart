import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/types/types_database_providers.dart';
import 'data/dto/character_skills.dart';
import 'data/dto/skill_queue_entry.dart';
import 'data/skill_repository.dart';
import 'domain/skill_notification_scheduler.dart';

final skillRepositoryProvider = Provider<SkillRepository>((ref) {
  return SkillRepository(ref.watch(esiClientProvider));
});

final skillNotificationSchedulerProvider =
    Provider<SkillNotificationScheduler>((ref) {
  return SkillNotificationScheduler(ref.watch(notificationServiceProvider));
});

/// Side-effect notifier that watches the known character set and, for each
/// character, listens to skillQueueProvider — firing the scheduler whenever
/// fresh queue data lands.
class SkillNotificationSync extends Notifier<void> {
  @override
  void build() {
    final tokens = ref.watch(storedCharactersProvider).value ?? const [];
    for (final t in tokens) {
      ref.listen<AsyncValue<SkillQueueData>>(
        skillQueueProvider(t.characterId),
        (prev, next) {
          next.whenData((data) {
            ref.read(skillNotificationSchedulerProvider).schedule(
                  characterId: t.characterId,
                  queue: data.queue,
                  skillNames: data.skillNames,
                );
          });
        },
        fireImmediately: true,
      );
    }
  }
}

final skillNotificationSyncProvider =
    NotifierProvider<SkillNotificationSync, void>(SkillNotificationSync.new);

class SkillQueueData {
  const SkillQueueData({
    required this.queue,
    required this.skills,
    required this.skillNames,
  });

  final List<SkillQueueEntry> queue;
  final CharacterSkills skills;
  final Map<int, String> skillNames;
}

class AllSkillsData {
  const AllSkillsData({required this.skills, required this.names});

  final CharacterSkills skills;
  final Map<int, String> names;
}

final allSkillsProvider =
    FutureProvider.family<AllSkillsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final skillRepo = ref.watch(skillRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final skills = await skillRepo.fetchSkills(characterId);
  final names = <int, String>{};
  for (final s in skills.skills) {
    final n = typesDb.lookup(s.skillId);
    if (n != null) names[s.skillId] = n;
  }

  return AllSkillsData(skills: skills, names: names);
});

/// Account state inferred from the skill queue, since ESI doesn't
/// expose Alpha/Omega directly. Picks the actively-training skill,
/// computes its SP/hour from `(level_end_sp - training_start_sp) /
/// (finish_date - start_date)`, and bins it: ~1500–2700 SP/h is
/// Omega-class, anything below ~1500 is Alpha (which trains at half
/// the Omega rate). Without an active skill we can't tell.
enum CloneState { alpha, omega, unknown }

final cloneStateProvider =
    FutureProvider.family<CloneState, int>((ref, characterId) async {
  final data = await ref.watch(skillQueueProvider(characterId).future);
  final now = DateTime.now();
  for (final e in data.queue) {
    final start = e.startDate;
    final finish = e.finishDate;
    if (start == null || finish == null) continue;
    if (finish.isBefore(now)) continue;
    final spStart = e.trainingStartSp ?? e.levelStartSp;
    final spDelta = e.levelEndSp - spStart;
    final secs = finish.difference(start).inSeconds;
    if (spDelta <= 0 || secs <= 0) continue;
    final spPerHour = spDelta * 3600 / secs;
    // Threshold sits roughly halfway between Alpha (~1350 SP/h at
    // mid attributes) and Omega (~2700 SP/h). Anything above that is
    // unambiguously paid; below it the queue is Alpha-throttled.
    return spPerHour >= 1800 ? CloneState.omega : CloneState.alpha;
  }
  return CloneState.unknown;
});

final skillQueueProvider =
    FutureProvider.family<SkillQueueData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final skills = ref.watch(skillRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final results = await Future.wait([
    skills.fetchQueue(characterId),
    skills.fetchSkills(characterId),
  ]);
  final queue = results[0] as List<SkillQueueEntry>;
  final summary = results[1] as CharacterSkills;

  final names = <int, String>{};
  for (final e in queue) {
    final n = typesDb.lookup(e.skillId);
    if (n != null) names[e.skillId] = n;
  }

  return SkillQueueData(queue: queue, skills: summary, skillNames: names);
});
