import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/fittings/data/dto/fitting.dart';
import 'package:neocompanion/features/fittings/domain/eft_format.dart';

void main() {
  test('exports header, ordered slot groups separated by blank lines', () {
    final fitting = Fitting(
      fittingId: 1,
      name: 'Test Fit',
      description: '',
      shipTypeId: 587,
      items: const [
        FittingItem(flag: 'HiSlot0', quantity: 1, typeId: 2873),
        FittingItem(flag: 'HiSlot1', quantity: 1, typeId: 2873),
        FittingItem(flag: 'MedSlot0', quantity: 1, typeId: 5973),
        FittingItem(flag: 'LoSlot0', quantity: 1, typeId: 519),
        FittingItem(flag: 'RigSlot0', quantity: 1, typeId: 31055),
      ],
    );
    final names = {
      587: 'Rifter',
      2873: '150mm Light AutoCannon I',
      5973: '1MN Afterburner I',
      519: 'Damage Control II',
      31055: 'Small Polycarbon Engine Housing I',
    };

    final out = exportEft(fitting, names);

    expect(out, '''[Rifter, Test Fit]

Damage Control II

1MN Afterburner I

150mm Light AutoCannon I
150mm Light AutoCannon I

Small Polycarbon Engine Housing I''');
  });

  test('appends quantities only for cargo, drones, and fighters', () {
    final fitting = Fitting(
      fittingId: 1,
      name: 'Cargo test',
      description: '',
      shipTypeId: 587,
      items: const [
        FittingItem(flag: 'HiSlot0', quantity: 1, typeId: 1),
        FittingItem(flag: 'DroneBay', quantity: 5, typeId: 2),
        FittingItem(flag: 'Cargo', quantity: 200, typeId: 3),
      ],
    );
    final names = {1: 'Gun', 2: 'Hobgoblin II', 3: 'EMP S'};

    final out = exportEft(fitting, names);
    expect(out, contains('Gun\n')); // no quantity on weapon
    expect(out, contains('Hobgoblin II x5'));
    expect(out, contains('EMP S x200'));
  });

  test('falls back to Type #id when name is missing', () {
    final fitting = Fitting(
      fittingId: 1,
      name: 'Unknown',
      description: '',
      shipTypeId: 99999,
      items: const [
        FittingItem(flag: 'HiSlot0', quantity: 1, typeId: 88888),
      ],
    );
    final out = exportEft(fitting, const {});
    expect(out, '''[Type #99999, Unknown]

Type #88888''');
  });
}
