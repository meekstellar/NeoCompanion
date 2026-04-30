import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/assets/asset_node.dart';
import 'package:neocompanion/features/assets/data/dto/asset_item.dart';

AssetItem _item(int itemId, int locationId,
    {int typeId = 1, bool singleton = false}) {
  return AssetItem(
    itemId: itemId,
    typeId: typeId,
    locationId: locationId,
    locationFlag: 'Hangar',
    locationType: locationId > 100 ? 'item' : 'station',
    quantity: 1,
    isSingleton: singleton,
    isBlueprintCopy: false,
  );
}

void main() {
  test('builds two-level tree from station/system roots', () {
    // station 60 holds a Bowhead (10) which holds a freighter (20).
    final tree = buildAssetTree([
      _item(10, 60, singleton: true),
      _item(20, 10, singleton: true),
    ]);
    expect(tree.rootsByLocation.keys, equals({60}));
    final bowhead = tree.rootsByLocation[60]!.single;
    expect(bowhead.item.itemId, 10);
    expect(bowhead.children.single.item.itemId, 20);
    expect(bowhead.totalDescendants, 1);
  });

  test('keeps siblings under a shared container', () {
    final tree = buildAssetTree([
      _item(100, 60, singleton: true),
      _item(101, 100), // ammo
      _item(102, 100), // module
      _item(103, 100), // drone
    ]);
    final container = tree.rootsByLocation[60]!.single;
    expect(container.children.length, 3);
    expect(container.totalDescendants, 3);
  });

  test('multiple top-level locations yield separate buckets', () {
    final tree = buildAssetTree([
      _item(10, 60),
      _item(20, 70),
      _item(21, 70),
    ]);
    expect(tree.rootsByLocation.keys.toSet(), equals({60, 70}));
    expect(tree.rootsByLocation[60]!.length, 1);
    expect(tree.rootsByLocation[70]!.length, 2);
  });

  test('three-level nesting (station > ship > can > ammo)', () {
    final tree = buildAssetTree([
      _item(1000, 60, singleton: true), // ship at station
      _item(2000, 1000, singleton: true), // can in ship's cargo
      _item(3000, 2000), // ammo stack in can
      _item(3001, 2000),
    ]);
    final ship = tree.rootsByLocation[60]!.single;
    final can = ship.children.single;
    expect(can.item.itemId, 2000);
    expect(can.children.length, 2);
    expect(ship.totalDescendants, 3); // can + 2 ammo
  });
}
