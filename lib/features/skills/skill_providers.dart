import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../characters/character_providers.dart';
import 'data/dto/character_skills.dart';
import 'data/dto/skill_queue_entry.dart';
import 'data/skill_repository.dart';

final skillRepositoryProvider = Provider<SkillRepository>((ref) {
  return SkillRepository(ref.watch(esiClientProvider));
});

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
