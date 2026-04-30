/// Response shape from `/characters/{id}/clones/`.
class ClonesData {
  const ClonesData({
    required this.homeLocation,
    required this.jumpClones,
    required this.lastCloneJumpDate,
    required this.lastStationChangeDate,
  });

  final CloneLocation? homeLocation;
  final List<JumpClone> jumpClones;
  final DateTime? lastCloneJumpDate;
  final DateTime? lastStationChangeDate;

  factory ClonesData.fromJson(Map<String, dynamic> json) {
    return ClonesData(
      homeLocation: json['home_location'] == null
          ? null
          : CloneLocation.fromJson(
              json['home_location'] as Map<String, dynamic>),
      jumpClones: (json['jump_clones'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(JumpClone.fromJson)
          .toList(),
      lastCloneJumpDate: _parseDate(json['last_clone_jump_date']),
      lastStationChangeDate: _parseDate(json['last_station_change_date']),
    );
  }
}

class CloneLocation {
  const CloneLocation({required this.locationId, required this.locationType});

  final int locationId;
  final String locationType;

  factory CloneLocation.fromJson(Map<String, dynamic> json) {
    return CloneLocation(
      locationId: (json['location_id'] as num).toInt(),
      locationType: json['location_type'] as String? ?? 'unknown',
    );
  }
}

class JumpClone {
  const JumpClone({
    required this.id,
    required this.location,
    required this.implants,
    this.name,
  });

  final int id;
  final CloneLocation location;
  final List<int> implants;
  final String? name;

  factory JumpClone.fromJson(Map<String, dynamic> json) {
    return JumpClone(
      id: (json['jump_clone_id'] as num).toInt(),
      location: CloneLocation(
        locationId: (json['location_id'] as num).toInt(),
        locationType: json['location_type'] as String? ?? 'unknown',
      ),
      implants: (json['implants'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      name: json['name'] as String?,
    );
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw);
}
