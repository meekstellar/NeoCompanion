/// One row from /characters/{id}/orders/.
class MarketOrder {
  const MarketOrder({
    required this.orderId,
    required this.typeId,
    required this.regionId,
    required this.locationId,
    required this.price,
    required this.volumeRemain,
    required this.volumeTotal,
    required this.duration,
    required this.issued,
    required this.isBuyOrder,
    this.range,
    this.minVolume,
  });

  final int orderId;
  final int typeId;
  final int regionId;
  final int locationId;
  final double price;
  final int volumeRemain;
  final int volumeTotal;
  final int duration;
  final DateTime issued;
  final bool isBuyOrder;
  final String? range;
  final int? minVolume;

  DateTime get expiresAt => issued.add(Duration(days: duration));

  factory MarketOrder.fromJson(Map<String, dynamic> json) {
    return MarketOrder(
      orderId: (json['order_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      regionId: (json['region_id'] as num).toInt(),
      locationId: (json['location_id'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      volumeRemain: (json['volume_remain'] as num).toInt(),
      volumeTotal: (json['volume_total'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      issued: DateTime.parse(json['issued'] as String),
      isBuyOrder: json['is_buy_order'] as bool? ?? false,
      range: json['range'] as String?,
      minVolume: (json['min_volume'] as num?)?.toInt(),
    );
  }
}
