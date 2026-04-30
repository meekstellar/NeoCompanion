/// One line on a contract: type, quantity, and whether it's part of
/// what's being offered (`isIncluded == true`) or what's requested in
/// return (`isIncluded == false`, common for "buy X for Y" item
/// exchanges).
class ContractItem {
  const ContractItem({
    required this.recordId,
    required this.typeId,
    required this.quantity,
    required this.rawQuantity,
    required this.isSingleton,
    required this.isIncluded,
  });

  final int recordId;
  final int typeId;
  final int quantity;

  /// Negative when the line represents a blueprint copy (CCP encoding):
  /// -1 for original, -2 for copy. Most callers can ignore this and
  /// just use [quantity], but we keep it so the detail screen can
  /// flag BPCs.
  final int rawQuantity;
  final bool isSingleton;
  final bool isIncluded;

  bool get isBlueprintCopy => rawQuantity == -2;

  factory ContractItem.fromJson(Map<String, dynamic> json) {
    return ContractItem(
      recordId: (json['record_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      rawQuantity: (json['raw_quantity'] as num?)?.toInt() ?? 0,
      isSingleton: json['is_singleton'] as bool? ?? false,
      isIncluded: json['is_included'] as bool? ?? true,
    );
  }
}
