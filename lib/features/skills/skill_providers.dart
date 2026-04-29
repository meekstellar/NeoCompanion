import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/network/network_providers.dart';
import '../../core/notifications/notification_providers.dart';
import '../characters/character_providers.dart';
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
  final skillRepo = ref.watch(skillRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final skills = await skillRepo.fetchSkills(characterId);
  final ids = skills.skills.map((s) => s.skillId).toSet().toList();

  var names = <int, String>{};
  if (ids.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(ids);
      names = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Fall back to raw IDs in the UI.
    }
  }

  return AllSkillsData(skills: skills, names: names);
});

final skillQueueProvider =
    FutureProvider.family<SkillQueueData, int>((ref, characterId) async {
  final skills = ref.watch(skillRepositoryProvider);
  final character = ref.watch(characterRepositoryProvider);

  final results = await Future.wait([
    skills.fetchQueue(characterId),
    skills.fetchSkills(characterId),
  ]);
  final queue = results[0] as List<SkillQueueEntry>;
  final summary = results[1] as CharacterSkills;

  final ids = queue.map((e) => e.skillId).toSet().toList();
  var names = <int, String>{};
  if (ids.isNotEmpty) {
    try {
      final resolved = await character.resolveNames(ids);
      names = {for (final n in resolved) n.id: n.name};
    } catch (_) {
      // Fall back to raw IDs in the UI.
    }
  }

  return SkillQueueData(queue: queue, skills: summary, skillNames: names);
});
