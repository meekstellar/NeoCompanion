/// One row in `/characters/{id}/skillqueue/`. A paused queue lacks
/// [startDate] and [finishDate]; SP fields are still present.
class SkillQueueEntry {
  const SkillQueueEntry({
    required this.skillId,
    required this.queuePosition,
    required this.finishedLevel,
    required this.levelStartSp,
    required this.levelEndSp,
    this.trainingStartSp,
    this.startDate,
    this.finishDate,
  });

  final int skillId;
  final int queuePosition;
  final int finishedLevel;
  final int levelStartSp;
  final int levelEndSp;
  final int? trainingStartSp;
  final DateTime? startDate;
  final DateTime? finishDate;

  bool get isPaused => startDate == null || finishDate == null;

  factory SkillQueueEntry.fromJson(Map<String, dynamic> json) {
    return SkillQueueEntry(
      skillId: json['skill_id'] as int,
      queuePosition: json['queue_position'] as int,
      finishedLevel: json['finished_level'] as int,
      levelStartSp: json['level_start_sp'] as int,
      levelEndSp: json['level_end_sp'] as int,
      trainingStartSp: json['training_start_sp'] as int?,
      startDate: _parseDate(json['start_date']),
      finishDate: _parseDate(json['finish_date']),
    );
  }
}

DateTime? _parseDate(Object? raw) =>
    raw is String ? DateTime.parse(raw) : null;
