import '../data/dto/fitting.dart';
import 'dogma_modifier.dart';
import 'slot_grouping.dart';

/// Well-known dogma attribute ids used by the resource computation.
/// IDs are stable in the SDE; names mirror CCP's `dogmaAttributes.json`.
class _Attr {
  static const int cpuOutput = 48;
  static const int powerOutput = 11;
  static const int upgradeCapacity = 1132;

  static const int cpu = 50;
  static const int power = 30;
  static const int upgradeCost = 1153;

  static const int hiSlots = 14;
  static const int medSlots = 13;
  static const int lowSlots = 12;
  static const int rigSlots = 1137;
  static const int maxSubSystems = 1367;

  static const int capacity = 38;
  static const int droneCapacity = 283;
  static const int droneBandwidth = 1271;
  static const int droneBandwidthUsed = 1272;
  static const int turretSlotsLeft = 102;
  static const int launcherSlotsLeft = 101;
}

/// SDE type ids for the small set of skills the fitting computation
/// applies. We hardcode the most-impactful ones (CPU/PG output and
/// weapon CPU/PG draw) — a complete dogma engine is post-MVP.
class FitSkill {
  static const int cpuManagement = 3426;
  static const int powerGridManagement = 3413;
  static const int weaponUpgrades = 3318;
  static const int advancedWeaponUpgrades = 11207;
}

/// Dogma effect ids that mark a module as consuming a hardpoint.
class _Effect {
  static const int launcherFitted = 40;
  static const int turretFitted = 42;
}

/// Static, skill-free, stacking-penalty-free view of a fit's loadout.
/// Stage 1 only — meant for "show me the fit" not "is this stable". Once
/// the dogma engine lands, this gets replaced by computed ship attributes.
class FitResources {
  const FitResources({
    required this.cpuUsed,
    required this.cpuMax,
    required this.powerUsed,
    required this.powerMax,
    required this.calibrationUsed,
    required this.calibrationMax,
    required this.cargoUsed,
    required this.cargoMax,
    required this.droneBayUsed,
    required this.droneBayMax,
    required this.droneBandwidthUsed,
    required this.droneBandwidthMax,
    required this.slots,
    required this.turretHardpoints,
    required this.launcherHardpoints,
  });

  final double cpuUsed;
  final double cpuMax;
  final double powerUsed;
  final double powerMax;
  final double calibrationUsed;
  final double calibrationMax;
  final double cargoUsed;
  final double cargoMax;
  final double droneBayUsed;
  final double droneBayMax;
  final double droneBandwidthUsed;
  final double droneBandwidthMax;
  final Map<FittingSlot, SlotUsage> slots;
  final SlotUsage turretHardpoints;
  final SlotUsage launcherHardpoints;
}

class SlotUsage {
  const SlotUsage({required this.used, required this.total});
  final int used;
  final int total;
}

FitResources computeFitResources({
  required Map<int, double> shipAttrs,
  required List<FittingItem> items,
  required Map<int, Map<int, double>> attrsByType,
  required Map<int, Set<int>> effectsByType,
  required Map<int, double> volumesByType,
  Map<int, int> skills = const {},
  Map<int, List<Modifier>> pilotMods = const {},
}) {
  double resolveShip(int attrId) {
    final base = shipAttrs[attrId] ?? 0;
    final mods = pilotMods[attrId];
    if (mods == null || mods.isEmpty) return base;
    return resolveAttribute(base, mods);
  }

  // Module-side discounts on weapon CPU/PG draw. Only applied to
  // modules that carry a turret or launcher hardpoint effect — these
  // skills don't touch other module types.
  final weaponUpg = skills[FitSkill.weaponUpgrades] ?? 0;
  final advWeaponUpg = skills[FitSkill.advancedWeaponUpgrades] ?? 0;
  final weaponCpuMul = 1.0 - 0.05 * weaponUpg;
  final weaponPowerMul = 1.0 - 0.10 * advWeaponUpg;

  double cpuUsed = 0, powerUsed = 0, calibrationUsed = 0;
  double cargoUsed = 0, droneBayUsed = 0, droneBandwidthUsed = 0;
  final slotUsed = <FittingSlot, int>{};
  int turretsUsed = 0, launchersUsed = 0;

  for (final item in items) {
    final slot = slotFor(item.flag);
    final attrs = attrsByType[item.typeId] ?? const {};
    final effects = effectsByType[item.typeId] ?? const <int>{};

    switch (slot) {
      case FittingSlot.highSlot:
      case FittingSlot.medSlot:
      case FittingSlot.lowSlot:
        final isWeapon = effects.contains(_Effect.turretFitted) ||
            effects.contains(_Effect.launcherFitted);
        final cpuMul = isWeapon ? weaponCpuMul : 1.0;
        final powerMul = isWeapon ? weaponPowerMul : 1.0;
        cpuUsed += (attrs[_Attr.cpu] ?? 0) * cpuMul * item.quantity;
        powerUsed += (attrs[_Attr.power] ?? 0) * powerMul * item.quantity;
        slotUsed.update(slot, (v) => v + item.quantity,
            ifAbsent: () => item.quantity);
        if (slot == FittingSlot.highSlot) {
          if (effects.contains(_Effect.turretFitted)) {
            turretsUsed += item.quantity;
          }
          if (effects.contains(_Effect.launcherFitted)) {
            launchersUsed += item.quantity;
          }
        }
      case FittingSlot.rigSlot:
        calibrationUsed += (attrs[_Attr.upgradeCost] ?? 0) * item.quantity;
        slotUsed.update(slot, (v) => v + item.quantity,
            ifAbsent: () => item.quantity);
      case FittingSlot.subsystem:
        slotUsed.update(slot, (v) => v + item.quantity,
            ifAbsent: () => item.quantity);
      case FittingSlot.drone:
        final vol = volumesByType[item.typeId] ?? 0;
        droneBayUsed += vol * item.quantity;
        droneBandwidthUsed +=
            (attrs[_Attr.droneBandwidthUsed] ?? 0) * item.quantity;
      case FittingSlot.cargo:
        final vol = volumesByType[item.typeId] ?? 0;
        cargoUsed += vol * item.quantity;
      case FittingSlot.service:
      case FittingSlot.fighter:
      case FittingSlot.other:
        break;
    }
  }

  final slots = <FittingSlot, SlotUsage>{
    FittingSlot.highSlot: SlotUsage(
      used: slotUsed[FittingSlot.highSlot] ?? 0,
      total: (shipAttrs[_Attr.hiSlots] ?? 0).toInt(),
    ),
    FittingSlot.medSlot: SlotUsage(
      used: slotUsed[FittingSlot.medSlot] ?? 0,
      total: (shipAttrs[_Attr.medSlots] ?? 0).toInt(),
    ),
    FittingSlot.lowSlot: SlotUsage(
      used: slotUsed[FittingSlot.lowSlot] ?? 0,
      total: (shipAttrs[_Attr.lowSlots] ?? 0).toInt(),
    ),
    FittingSlot.rigSlot: SlotUsage(
      used: slotUsed[FittingSlot.rigSlot] ?? 0,
      total: (shipAttrs[_Attr.rigSlots] ?? 0).toInt(),
    ),
  };
  final subsystemMax = (shipAttrs[_Attr.maxSubSystems] ?? 0).toInt();
  if (subsystemMax > 0 || (slotUsed[FittingSlot.subsystem] ?? 0) > 0) {
    slots[FittingSlot.subsystem] = SlotUsage(
      used: slotUsed[FittingSlot.subsystem] ?? 0,
      total: subsystemMax,
    );
  }

  return FitResources(
    cpuUsed: cpuUsed,
    cpuMax: resolveShip(_Attr.cpuOutput),
    powerUsed: powerUsed,
    powerMax: resolveShip(_Attr.powerOutput),
    calibrationUsed: calibrationUsed,
    calibrationMax: shipAttrs[_Attr.upgradeCapacity] ?? 0,
    cargoUsed: cargoUsed,
    cargoMax: shipAttrs[_Attr.capacity] ?? 0,
    droneBayUsed: droneBayUsed,
    droneBayMax: shipAttrs[_Attr.droneCapacity] ?? 0,
    droneBandwidthUsed: droneBandwidthUsed,
    droneBandwidthMax: shipAttrs[_Attr.droneBandwidth] ?? 0,
    slots: slots,
    turretHardpoints: SlotUsage(
      used: turretsUsed,
      total: (shipAttrs[_Attr.turretSlotsLeft] ?? 0).toInt(),
    ),
    launcherHardpoints: SlotUsage(
      used: launchersUsed,
      total: (shipAttrs[_Attr.launcherSlotsLeft] ?? 0).toInt(),
    ),
  );
}
