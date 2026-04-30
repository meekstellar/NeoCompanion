/// One row from `/universe/structures/{structure_id}/` — the
/// authorized lookup that resolves player-anchored citadels (Astrahus,
/// Fortizar, Keepstar, …). Unlike `/universe/names/`, this requires the
/// caller to have docking access to the structure; missing access
/// surfaces as 403 and the field is left absent in the asset list.
class StructureInfo {
  const StructureInfo({
    required this.structureId,
    required this.name,
    required this.solarSystemId,
    required this.typeId,
    required this.ownerId,
  });

  final int structureId;
  final String name;
  final int solarSystemId;
  final int? typeId;
  final int? ownerId;

  factory StructureInfo.fromJson(int id, Map<String, dynamic> json) {
    return StructureInfo(
      structureId: id,
      name: json['name'] as String,
      solarSystemId: (json['solar_system_id'] as num).toInt(),
      typeId: (json['type_id'] as num?)?.toInt(),
      ownerId: (json['owner_id'] as num?)?.toInt(),
    );
  }
}
