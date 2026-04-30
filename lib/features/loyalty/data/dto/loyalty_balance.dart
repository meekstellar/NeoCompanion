/// One row from `/characters/{id}/loyalty/points/`: how many loyalty
/// points the character currently holds with a given NPC corporation.
class LoyaltyBalance {
  const LoyaltyBalance({
    required this.corporationId,
    required this.loyaltyPoints,
  });

  final int corporationId;
  final int loyaltyPoints;

  factory LoyaltyBalance.fromJson(Map<String, dynamic> json) {
    return LoyaltyBalance(
      corporationId: (json['corporation_id'] as num).toInt(),
      loyaltyPoints: (json['loyalty_points'] as num).toInt(),
    );
  }
}
