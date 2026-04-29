import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/assets/data/dto/asset_item.dart';

void main() {
  test('parses 64-bit IDs and BPC flag', () {
    final dto = AssetItem.fromJson({
      'item_id': 1000000016991,
      'type_id': 587,
      'location_id': 60003760,
      'location_flag': 'Hangar',
      'location_type': 'station',
      'quantity': 5,
      'is_singleton': false,
      'is_blueprint_copy': true,
    });
    expect(dto.itemId, 1000000016991);
    expect(dto.typeId, 587);
    expect(dto.locationId, 60003760);
    expect(dto.locationFlag, 'Hangar');
    expect(dto.locationType, 'station');
    expect(dto.quantity, 5);
    expect(dto.isBlueprintCopy, isTrue);
  });

  test('defaults missing optionals', () {
    final dto = AssetItem.fromJson({
      'item_id': 1,
      'type_id': 2,
      'location_id': 3,
      'location_flag': 'Cargo',
      'location_type': 'item',
    });
    expect(dto.quantity, 1);
    expect(dto.isSingleton, isFalse);
    expect(dto.isBlueprintCopy, isFalse);
  });
}
