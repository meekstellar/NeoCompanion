enum UniverseNameCategory {
  alliance,
  character,
  constellation,
  corporation,
  faction,
  inventoryType,
  region,
  solarSystem,
  station,
  unknown;

  static UniverseNameCategory parse(String raw) => switch (raw) {
        'alliance' => alliance,
        'character' => character,
        'constellation' => constellation,
        'corporation' => corporation,
        'faction' => faction,
        'inventory_type' => inventoryType,
        'region' => region,
        'solar_system' => solarSystem,
        'station' => station,
        _ => unknown,
      };
}

class UniverseName {
  const UniverseName({
    required this.id,
    required this.name,
    required this.category,
  });

  final int id;
  final String name;
  final UniverseNameCategory category;

  factory UniverseName.fromJson(Map<String, dynamic> json) {
    return UniverseName(
      id: json['id'] as int,
      name: json['name'] as String,
      category: UniverseNameCategory.parse(json['category'] as String),
    );
  }
}
