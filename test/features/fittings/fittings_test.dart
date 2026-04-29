import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/fittings/data/dto/fitting.dart';
import 'package:neocompanion/features/fittings/domain/slot_grouping.dart';

void main() {
  group('Fitting parsing', () {
    test('parses fitting with items and missing description', () {
      final fitting = Fitting.fromJson({
        'fitting_id': 1,
        'name': 'Rifter PvP',
        'ship_type_id': 587,
        'items': [
          {'flag': 'HiSlot0', 'quantity': 1, 'type_id': 2873},
          {'flag': 'Cargo', 'quantity': 200, 'type_id': 12608},
        ],
      });
      expect(fitting.fittingId, 1);
      expect(fitting.name, 'Rifter PvP');
      expect(fitting.description, '');
      expect(fitting.items.length, 2);
      expect(fitting.items.first.flag, 'HiSlot0');
      expect(fitting.items.last.quantity, 200);
    });
  });

  group('slotFor', () {
    test('maps slot prefixes to the right slot enum', () {
      expect(slotFor('HiSlot0'), FittingSlot.highSlot);
      expect(slotFor('MedSlot3'), FittingSlot.medSlot);
      expect(slotFor('LoSlot7'), FittingSlot.lowSlot);
      expect(slotFor('RigSlot1'), FittingSlot.rigSlot);
      expect(slotFor('SubSystemSlot0'), FittingSlot.subsystem);
      expect(slotFor('ServiceSlot2'), FittingSlot.service);
      expect(slotFor('DroneBay'), FittingSlot.drone);
      expect(slotFor('FighterBay'), FittingSlot.fighter);
      expect(slotFor('Cargo'), FittingSlot.cargo);
      expect(slotFor('Wallet'), FittingSlot.other);
    });
  });

  group('groupBySlot', () {
    test('buckets items by slot, preserves slot order, omits empty buckets',
        () {
      final items = [
        const FittingItem(flag: 'HiSlot0', quantity: 1, typeId: 1),
        const FittingItem(flag: 'Cargo', quantity: 50, typeId: 2),
        const FittingItem(flag: 'HiSlot1', quantity: 1, typeId: 3),
        const FittingItem(flag: 'LoSlot0', quantity: 1, typeId: 4),
      ];
      final grouped = groupBySlot(items);
      expect(grouped.keys.toList(), [
        FittingSlot.highSlot,
        FittingSlot.lowSlot,
        FittingSlot.cargo,
      ]);
      expect(grouped[FittingSlot.highSlot]!.length, 2);
      expect(grouped[FittingSlot.cargo]!.single.quantity, 50);
    });
  });
}
