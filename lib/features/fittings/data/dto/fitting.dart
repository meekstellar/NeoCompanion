class Fitting {
  const Fitting({
    required this.fittingId,
    required this.name,
    required this.description,
    required this.shipTypeId,
    required this.items,
  });

  final int fittingId;
  final String name;
  final String description;
  final int shipTypeId;
  final List<FittingItem> items;

  factory Fitting.fromJson(Map<String, dynamic> json) {
    return Fitting(
      fittingId: (json['fitting_id'] as num).toInt(),
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      shipTypeId: (json['ship_type_id'] as num).toInt(),
      items: (json['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(FittingItem.fromJson)
          .toList(),
    );
  }
}

class FittingItem {
  const FittingItem({
    required this.flag,
    required this.quantity,
    required this.typeId,
  });

  final String flag;
  final int quantity;
  final int typeId;

  factory FittingItem.fromJson(Map<String, dynamic> json) {
    return FittingItem(
      flag: json['flag'] as String,
      quantity: (json['quantity'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
    );
  }
}
