/// One row from /characters/{id}/assets/.
class AssetItem {
  const AssetItem({
    required this.itemId,
    required this.typeId,
    required this.locationId,
    required this.locationFlag,
    required this.locationType,
    required this.quantity,
    required this.isSingleton,
    required this.isBlueprintCopy,
  });

  final int itemId;
  final int typeId;
  final int locationId;
  final String locationFlag;
  final String locationType;
  final int quantity;
  final bool isSingleton;
  final bool isBlueprintCopy;

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      itemId: (json['item_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      locationId: (json['location_id'] as num).toInt(),
      locationFlag: json['location_flag'] as String,
      locationType: json['location_type'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isSingleton: json['is_singleton'] as bool? ?? false,
      isBlueprintCopy: json['is_blueprint_copy'] as bool? ?? false,
    );
  }
}
