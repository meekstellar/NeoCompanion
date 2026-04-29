import '../data/dto/fitting.dart';

enum FittingSlot {
  highSlot,
  medSlot,
  lowSlot,
  rigSlot,
  subsystem,
  service,
  drone,
  fighter,
  cargo,
  other;

  String get title => switch (this) {
        FittingSlot.highSlot => 'High slots',
        FittingSlot.medSlot => 'Mid slots',
        FittingSlot.lowSlot => 'Low slots',
        FittingSlot.rigSlot => 'Rigs',
        FittingSlot.subsystem => 'Subsystems',
        FittingSlot.service => 'Services',
        FittingSlot.drone => 'Drones',
        FittingSlot.fighter => 'Fighters',
        FittingSlot.cargo => 'Cargo',
        FittingSlot.other => 'Other',
      };
}

/// Maps an ESI [FittingItem.flag] to the user-facing [FittingSlot].
/// Flags look like 'HiSlot0', 'LoSlot7', 'RigSlot2', 'Cargo', 'DroneBay', ...
FittingSlot slotFor(String flag) {
  if (flag.startsWith('HiSlot')) return FittingSlot.highSlot;
  if (flag.startsWith('MedSlot')) return FittingSlot.medSlot;
  if (flag.startsWith('LoSlot')) return FittingSlot.lowSlot;
  if (flag.startsWith('RigSlot')) return FittingSlot.rigSlot;
  if (flag.startsWith('SubSystemSlot')) return FittingSlot.subsystem;
  if (flag.startsWith('ServiceSlot')) return FittingSlot.service;
  if (flag == 'DroneBay') return FittingSlot.drone;
  if (flag == 'FighterBay') return FittingSlot.fighter;
  if (flag == 'Cargo') return FittingSlot.cargo;
  return FittingSlot.other;
}

/// Buckets [items] by slot, preserving the natural slot order from
/// [FittingSlot]. Empty buckets are omitted.
Map<FittingSlot, List<FittingItem>> groupBySlot(Iterable<FittingItem> items) {
  final result = <FittingSlot, List<FittingItem>>{};
  for (final slot in FittingSlot.values) {
    final inSlot = items.where((i) => slotFor(i.flag) == slot).toList();
    if (inSlot.isNotEmpty) result[slot] = inSlot;
  }
  return result;
}
