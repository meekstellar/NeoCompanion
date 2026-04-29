class CharacterShip {
  const CharacterShip({
    required this.shipTypeId,
    required this.shipItemId,
    required this.shipName,
  });

  final int shipTypeId;
  final int shipItemId;
  final String shipName;

  factory CharacterShip.fromJson(Map<String, dynamic> json) {
    return CharacterShip(
      shipTypeId: json['ship_type_id'] as int,
      shipItemId: (json['ship_item_id'] as num).toInt(),
      shipName: json['ship_name'] as String,
    );
  }
}
