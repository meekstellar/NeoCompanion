import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/market/data/dto/market_order.dart';

void main() {
  test('parses a sell order with all fields', () {
    final dto = MarketOrder.fromJson({
      'order_id': 4623562346,
      'type_id': 34,
      'region_id': 10000002,
      'location_id': 60003760,
      'price': 5.99,
      'volume_remain': 12500000,
      'volume_total': 50000000,
      'duration': 90,
      'issued': '2026-04-20T10:00:00Z',
      'is_buy_order': false,
      'range': 'station',
    });
    expect(dto.orderId, 4623562346);
    expect(dto.isBuyOrder, isFalse);
    expect(dto.price, 5.99);
    expect(dto.range, 'station');
    expect(dto.expiresAt.difference(dto.issued).inDays, 90);
  });

  test('treats missing is_buy_order as false (sell)', () {
    final dto = MarketOrder.fromJson({
      'order_id': 1,
      'type_id': 1,
      'region_id': 1,
      'location_id': 1,
      'price': 1.0,
      'volume_remain': 1,
      'volume_total': 1,
      'duration': 1,
      'issued': '2026-04-20T10:00:00Z',
    });
    expect(dto.isBuyOrder, isFalse);
  });
}
