/// Response from `/characters/{id}/attributes/`.
class CharacterAttributes {
  const CharacterAttributes({
    required this.charisma,
    required this.intelligence,
    required this.memory,
    required this.perception,
    required this.willpower,
    required this.bonusRemaps,
    this.accruedRemapCooldownDate,
    this.lastRemapDate,
  });

  final int charisma;
  final int intelligence;
  final int memory;
  final int perception;
  final int willpower;
  final int bonusRemaps;
  final DateTime? accruedRemapCooldownDate;
  final DateTime? lastRemapDate;

  factory CharacterAttributes.fromJson(Map<String, dynamic> json) {
    return CharacterAttributes(
      charisma: (json['charisma'] as num?)?.toInt() ?? 0,
      intelligence: (json['intelligence'] as num?)?.toInt() ?? 0,
      memory: (json['memory'] as num?)?.toInt() ?? 0,
      perception: (json['perception'] as num?)?.toInt() ?? 0,
      willpower: (json['willpower'] as num?)?.toInt() ?? 0,
      bonusRemaps: (json['bonus_remaps'] as num?)?.toInt() ?? 0,
      accruedRemapCooldownDate: _parse(json['accrued_remap_cooldown_date']),
      lastRemapDate: _parse(json['last_remap_date']),
    );
  }
}

DateTime? _parse(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw);
}
