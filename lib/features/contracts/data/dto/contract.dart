/// One row from `/characters/{id}/contracts/`. Captures everything
/// useful for both the list cell and the detail screen so callers
/// don't have to re-fetch.
class Contract {
  const Contract({
    required this.contractId,
    required this.issuerId,
    required this.assigneeId,
    required this.type,
    required this.status,
    required this.availability,
    required this.title,
    required this.forCorporation,
    required this.dateIssued,
    required this.dateExpired,
    required this.dateAccepted,
    required this.dateCompleted,
    required this.daysToComplete,
    required this.startLocationId,
    required this.endLocationId,
    required this.price,
    required this.reward,
    required this.collateral,
    required this.buyout,
    required this.volume,
  });

  final int contractId;
  final int issuerId;
  final int? assigneeId;
  final String type;
  final String status;
  final String availability;
  final String title;
  final bool forCorporation;
  final DateTime dateIssued;
  final DateTime dateExpired;
  final DateTime? dateAccepted;
  final DateTime? dateCompleted;
  final int? daysToComplete;
  final int? startLocationId;
  final int? endLocationId;
  final double price;
  final double reward;
  final double collateral;
  final double buyout;
  final double volume;

  bool get isCourier => type == 'courier';
  bool get isAuction => type == 'auction';
  bool get isItemExchange => type == 'item_exchange';

  factory Contract.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.parse(v) : null;
    double parseDouble(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    return Contract(
      contractId: (json['contract_id'] as num).toInt(),
      issuerId: (json['issuer_id'] as num).toInt(),
      assigneeId: (json['assignee_id'] as num?)?.toInt(),
      type: json['type'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      availability: json['availability'] as String? ?? 'unknown',
      title: (json['title'] as String? ?? '').trim(),
      forCorporation: json['for_corporation'] as bool? ?? false,
      dateIssued: DateTime.parse(json['date_issued'] as String),
      dateExpired: DateTime.parse(json['date_expired'] as String),
      dateAccepted: parseDate(json['date_accepted']),
      dateCompleted: parseDate(json['date_completed']),
      daysToComplete: (json['days_to_complete'] as num?)?.toInt(),
      startLocationId: (json['start_location_id'] as num?)?.toInt(),
      endLocationId: (json['end_location_id'] as num?)?.toInt(),
      price: parseDouble(json['price']),
      reward: parseDouble(json['reward']),
      collateral: parseDouble(json['collateral']),
      buyout: parseDouble(json['buyout']),
      volume: parseDouble(json['volume']),
    );
  }
}
