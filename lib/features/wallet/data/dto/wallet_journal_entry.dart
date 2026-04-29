/// One row from /characters/{id}/wallet/journal/.
class WalletJournalEntry {
  const WalletJournalEntry({
    required this.id,
    required this.refType,
    required this.date,
    required this.amount,
    this.balance,
    this.description,
    this.reason,
    this.firstPartyId,
    this.secondPartyId,
    this.tax,
    this.taxReceiverId,
  });

  final int id;
  final String refType;
  final DateTime date;
  final double amount;
  final double? balance;
  final String? description;
  final String? reason;
  final int? firstPartyId;
  final int? secondPartyId;
  final double? tax;
  final int? taxReceiverId;

  factory WalletJournalEntry.fromJson(Map<String, dynamic> json) {
    return WalletJournalEntry(
      id: (json['id'] as num).toInt(),
      refType: json['ref_type'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble(),
      description: json['description'] as String?,
      reason: json['reason'] as String?,
      firstPartyId: (json['first_party_id'] as num?)?.toInt(),
      secondPartyId: (json['second_party_id'] as num?)?.toInt(),
      tax: (json['tax'] as num?)?.toDouble(),
      taxReceiverId: (json['tax_receiver_id'] as num?)?.toInt(),
    );
  }
}
