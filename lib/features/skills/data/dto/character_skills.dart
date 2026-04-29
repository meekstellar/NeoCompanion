class CharacterSkills {
  const CharacterSkills({
    required this.totalSp,
    required this.unallocatedSp,
    required this.skills,
  });

  final int totalSp;
  final int unallocatedSp;
  final List<SkillSummary> skills;

  factory CharacterSkills.fromJson(Map<String, dynamic> json) {
    final raw = (json['skills'] as List).cast<Map<String, dynamic>>();
    return CharacterSkills(
      totalSp: (json['total_sp'] as num).toInt(),
      unallocatedSp: (json['unallocated_sp'] as num?)?.toInt() ?? 0,
      skills: raw.map(SkillSummary.fromJson).toList(),
    );
  }
}

class SkillSummary {
  const SkillSummary({
    required this.skillId,
    required this.skillpointsInSkill,
    required this.trainedSkillLevel,
    required this.activeSkillLevel,
  });

  final int skillId;
  final int skillpointsInSkill;
  final int trainedSkillLevel;
  final int activeSkillLevel;

  factory SkillSummary.fromJson(Map<String, dynamic> json) {
    return SkillSummary(
      skillId: json['skill_id'] as int,
      skillpointsInSkill: (json['skillpoints_in_skill'] as num).toInt(),
      trainedSkillLevel: json['trained_skill_level'] as int,
      activeSkillLevel: json['active_skill_level'] as int,
    );
  }
}
