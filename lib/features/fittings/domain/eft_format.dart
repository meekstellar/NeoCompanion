import '../data/dto/fitting.dart';
import 'slot_grouping.dart';

/// Conventional EFT module section order. The header `[Ship, Name]` comes
/// first, then each slot group is separated by a blank line.
const _eftSlotOrder = <FittingSlot>[
  FittingSlot.lowSlot,
  FittingSlot.medSlot,
  FittingSlot.highSlot,
  FittingSlot.rigSlot,
  FittingSlot.subsystem,
  FittingSlot.service,
  FittingSlot.drone,
  FittingSlot.fighter,
  FittingSlot.cargo,
];

/// Renders [fitting] in EFT format. Returns a string that EFT, Pyfa, and
/// EVE's in-game fitting tool all accept on paste.
///
/// Modules in fixed slots come out one per line. Drones, fighters, and
/// cargo items add ` xN` for quantities greater than one. Unknown ids
/// fall back to `Type #1234` so the output stays parseable.
String exportEft(Fitting fitting, Map<int, String> typeNames) {
  final ship = typeNames[fitting.shipTypeId] ?? 'Type #${fitting.shipTypeId}';
  final buffer = StringBuffer()
    ..writeln('[$ship, ${fitting.name}]');

  final grouped = groupBySlot(fitting.items);

  for (final slot in _eftSlotOrder) {
    final items = grouped[slot];
    if (items == null || items.isEmpty) continue;
    buffer.writeln();
    final showQuantity = _slotsWithQuantity.contains(slot);
    for (final item in items) {
      final name = typeNames[item.typeId] ?? 'Type #${item.typeId}';
      if (showQuantity && item.quantity > 1) {
        buffer.writeln('$name x${item.quantity}');
      } else {
        buffer.writeln(name);
      }
    }
  }

  return buffer.toString().trimRight();
}

const _slotsWithQuantity = <FittingSlot>{
  FittingSlot.drone,
  FittingSlot.fighter,
  FittingSlot.cargo,
};
