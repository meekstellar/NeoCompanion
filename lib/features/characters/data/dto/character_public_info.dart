class CharacterPublicInfo {
  const CharacterPublicInfo({
    required this.name,
    required this.corporationId,
    required this.securityStatus,
    required this.birthday,
    this.allianceId,
    this.factionId,
    this.raceId,
    this.bloodlineId,
    this.title,
  });

  final String name;
  final int corporationId;
  final double securityStatus;
  final DateTime birthday;
  final int? allianceId;
  final int? factionId;
  final int? raceId;
  final int? bloodlineId;
  final String? title;

  factory CharacterPublicInfo.fromJson(Map<String, dynamic> json) {
    return CharacterPublicInfo(
      name: json['name'] as String,
      corporationId: json['corporation_id'] as int,
      securityStatus: (json['security_status'] as num?)?.toDouble() ?? 0.0,
      birthday: DateTime.parse(json['birthday'] as String),
      allianceId: json['alliance_id'] as int?,
      factionId: json['faction_id'] as int?,
      raceId: json['race_id'] as int?,
      bloodlineId: json['bloodline_id'] as int?,
      title: json['title'] as String?,
    );
  }
}
