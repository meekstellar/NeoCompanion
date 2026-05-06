/// One row from /characters/{id}/wallet/transactions/.
class WalletTransactionEntry {
  const WalletTransactionEntry({
    required this.transactionId,
    required this.date,
    required this.typeId,
    required this.quantity,
    required this.unitPrice,
    required this.isBuy,
    required this.isPersonal,
    required this.clientId,
    required this.locationId,
    required this.journalRefId,
  });

  final int transactionId;
  final DateTime date;
  final int typeId;
  final int quantity;
  final double unitPrice;
  final bool isBuy;
  final bool isPersonal;
  final int clientId;
  final int locationId;
  final int journalRefId;

  double get total => unitPrice * quantity;

  factory WalletTransactionEntry.fromJson(Map<String, dynamic> json) {
    return WalletTransactionEntry(
      transactionId: (json['transaction_id'] as num).toInt(),
      date: DateTime.parse(json['date'] as String),
      typeId: (json['type_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      isBuy: json['is_buy'] as bool,
      isPersonal: json['is_personal'] as bool,
      clientId: (json['client_id'] as num).toInt(),
      locationId: (json['location_id'] as num).toInt(),
      journalRefId: (json['journal_ref_id'] as num).toInt(),
    );
  }
}
