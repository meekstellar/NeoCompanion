/// One row from `/characters/{id}/planets/`. Top-level summary of a
/// PI colony — system, planet type, and how built-out the colony is.
/// The detailed pin / link / route layout lives behind a separate
/// per-planet endpoint that we don't need for the list screen.
class PlanetSummary {
  const PlanetSummary({
    required this.solarSystemId,
    required this.planetId,
    required this.planetType,
    required this.ownerId,
    required this.lastUpdate,
    required this.upgradeLevel,
    required this.numPins,
  });

  final int solarSystemId;
  final int planetId;

  /// "barren" | "gas" | "ice" | "lava" | "oceanic" | "plasma" |
  /// "storm" | "temperate"
  final String planetType;
  final int ownerId;
  final DateTime lastUpdate;
  final int upgradeLevel;
  final int numPins;

  factory PlanetSummary.fromJson(Map<String, dynamic> json) {
    return PlanetSummary(
      solarSystemId: (json['solar_system_id'] as num).toInt(),
      planetId: (json['planet_id'] as num).toInt(),
      planetType: json['planet_type'] as String? ?? 'unknown',
      ownerId: (json['owner_id'] as num).toInt(),
      lastUpdate: DateTime.parse(json['last_update'] as String),
      upgradeLevel: (json['upgrade_level'] as num?)?.toInt() ?? 0,
      numPins: (json['num_pins'] as num?)?.toInt() ?? 0,
    );
  }
}
