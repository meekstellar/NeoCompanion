import '../../../core/network/esi_client.dart';
import 'dto/character_skills.dart';
import 'dto/skill_queue_entry.dart';

class SkillRepository {
  SkillRepository(this._esi);

  final EsiClient _esi;

  Future<List<SkillQueueEntry>> fetchQueue(int characterId) async {
    final res = await _esi.get<List<dynamic>>(
      '/characters/$characterId/skillqueue/',
      characterId: characterId,
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SkillQueueEntry.fromJson)
        .toList()
      ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
  }

  Future<CharacterSkills> fetchSkills(int characterId) async {
    final res = await _esi.get<Map<String, dynamic>>(
      '/characters/$characterId/skills/',
      characterId: characterId,
    );
    return CharacterSkills.fromJson(res.data!);
  }
}
