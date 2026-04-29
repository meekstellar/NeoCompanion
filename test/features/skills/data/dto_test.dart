import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/skills/data/dto/character_skills.dart';
import 'package:neocompanion/features/skills/data/dto/skill_queue_entry.dart';

void main() {
  group('SkillQueueEntry', () {
    test('parses an actively-training entry', () {
      final dto = SkillQueueEntry.fromJson({
        'skill_id': 3327,
        'queue_position': 0,
        'finished_level': 4,
        'level_start_sp': 45255,
        'level_end_sp': 256000,
        'training_start_sp': 50000,
        'start_date': '2026-04-29T10:00:00Z',
        'finish_date': '2026-04-30T10:00:00Z',
      });
      expect(dto.skillId, 3327);
      expect(dto.queuePosition, 0);
      expect(dto.isPaused, isFalse);
      expect(dto.startDate!.year, 2026);
      expect(dto.levelEndSp, 256000);
    });

    test('parses a paused entry without dates', () {
      final dto = SkillQueueEntry.fromJson({
        'skill_id': 3300,
        'queue_position': 5,
        'finished_level': 3,
        'level_start_sp': 8000,
        'level_end_sp': 45255,
      });
      expect(dto.isPaused, isTrue);
      expect(dto.startDate, isNull);
      expect(dto.finishDate, isNull);
    });
  });

  group('CharacterSkills', () {
    test('parses total SP and individual skills', () {
      final dto = CharacterSkills.fromJson({
        'total_sp': 95000000,
        'unallocated_sp': 50000,
        'skills': [
          {
            'skill_id': 3327,
            'skillpoints_in_skill': 256000,
            'trained_skill_level': 5,
            'active_skill_level': 5,
          },
          {
            'skill_id': 3300,
            'skillpoints_in_skill': 45255,
            'trained_skill_level': 4,
            'active_skill_level': 4,
          },
        ],
      });
      expect(dto.totalSp, 95000000);
      expect(dto.unallocatedSp, 50000);
      expect(dto.skills.length, 2);
      expect(dto.skills.first.skillId, 3327);
    });

    test('treats missing unallocated_sp as 0', () {
      final dto = CharacterSkills.fromJson({
        'total_sp': 1000,
        'skills': <Map<String, dynamic>>[],
      });
      expect(dto.unallocatedSp, 0);
    });
  });
}
