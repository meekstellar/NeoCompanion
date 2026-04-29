class CharacterLocation {
  const CharacterLocation({
    required this.solarSystemId,
    this.stationId,
    this.structureId,
  });

  final int solarSystemId;
  final int? stationId;
  final int? structureId;

  factory CharacterLocation.fromJson(Map<String, dynamic> json) {
    return CharacterLocation(
      solarSystemId: json['solar_system_id'] as int,
      stationId: json['station_id'] as int?,
      structureId: (json['structure_id'] as num?)?.toInt(),
    );
  }
}
