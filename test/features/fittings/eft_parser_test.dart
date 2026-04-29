import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/fittings/domain/eft_parser.dart';
import 'package:neocompanion/features/fittings/domain/parsed_to_payload.dart';
import 'package:neocompanion/features/fittings/domain/slot_grouping.dart';

void main() {
  group('parseEft', () {
    test('extracts header, slot order, and quantities', () {
      const text = '''[Rifter, Brawler]

Damage Control II

1MN Afterburner II
Stasis Webifier II

200mm AutoCannon II
200mm AutoCannon II

Small Projectile Burst Aerator I

Hobgoblin II x4

Republic Fleet Phased Plasma S x500
''';
      final parsed = parseEft(text);
      expect(parsed.shipName, 'Rifter');
      expect(parsed.fitName, 'Brawler');

      final lo = parsed.items.where((i) => i.slot == FittingSlot.lowSlot).toList();
      final mid = parsed.items.where((i) => i.slot == FittingSlot.medSlot).toList();
      final hi = parsed.items.where((i) => i.slot == FittingSlot.highSlot).toList();
      final rig = parsed.items.where((i) => i.slot == FittingSlot.rigSlot).toList();
      final drone = parsed.items.where((i) => i.slot == FittingSlot.drone).toList();
      final cargo = parsed.items.where((i) => i.slot == FittingSlot.cargo).toList();

      expect(lo.single.name, 'Damage Control II');
      expect(mid.length, 2);
      expect(hi.length, 2);
      expect(rig.single.name, 'Small Projectile Burst Aerator I');
      expect(drone.single.name, 'Hobgoblin II');
      expect(drone.single.quantity, 4);
      expect(cargo.single.name, 'Republic Fleet Phased Plasma S');
      expect(cargo.single.quantity, 500);
    });

    test('skips [Empty * slot] placeholders without shifting slot order', () {
      const text = '''[Rifter, Sparse]

Damage Control II

[Empty Med slot]
[Empty Med slot]

200mm AutoCannon II
''';
      final parsed = parseEft(text);
      expect(parsed.items.length, 2);
      expect(parsed.items[0].slot, FittingSlot.lowSlot);
      expect(parsed.items[1].slot, FittingSlot.highSlot);
    });

    test('throws when header is missing', () {
      expect(
        () => parseEft('Damage Control II\n'),
        throwsA(isA<EftParseException>()),
      );
    });

    test('throws when nothing parses', () {
      expect(
        () => parseEft('[Rifter, Empty]\n'),
        throwsA(isA<EftParseException>()),
      );
    });
  });

  group('toPayload', () {
    test('produces ESI flags with per-slot indexing', () {
      final parsed = parseEft('''[Rifter, T]

Damage Control II
Tracking Enhancer II

1MN Afterburner II

200mm AutoCannon II
200mm AutoCannon II
200mm AutoCannon II

Hobgoblin II x4

Republic Fleet Phased Plasma S x500
''');
      final ids = {
        'Rifter': 587,
        'Damage Control II': 519,
        'Tracking Enhancer II': 1999,
        '1MN Afterburner II': 5973,
        '200mm AutoCannon II': 2873,
        'Hobgoblin II': 2456,
        'Republic Fleet Phased Plasma S': 21896,
      };

      final payload = toPayload(parsed, ids);
      expect(payload.shipTypeId, 587);
      expect(payload.unresolvedNames, isEmpty);

      final flags = payload.items.map((i) => i.flag).toList();
      expect(flags.where((f) => f.startsWith('LoSlot')).toList(),
          ['LoSlot0', 'LoSlot1']);
      expect(flags.where((f) => f.startsWith('MedSlot')).toList(),
          ['MedSlot0']);
      expect(flags.where((f) => f.startsWith('HiSlot')).toList(),
          ['HiSlot0', 'HiSlot1', 'HiSlot2']);
      expect(flags.where((f) => f == 'DroneBay').length, 1);
      expect(flags.where((f) => f == 'Cargo').length, 1);

      final drone = payload.items.firstWhere((i) => i.flag == 'DroneBay');
      expect(drone.quantity, 4);
      final cargo = payload.items.firstWhere((i) => i.flag == 'Cargo');
      expect(cargo.quantity, 500);
    });

    test('reports unresolved names instead of crashing', () {
      final parsed = parseEft('''[Rifter, T]

Damage Control II
Some Mythical Module
''');
      final ids = {'Rifter': 587, 'Damage Control II': 519};
      final payload = toPayload(parsed, ids);
      expect(payload.unresolvedNames, ['Some Mythical Module']);
      expect(payload.items.length, 1);
    });
  });
}
