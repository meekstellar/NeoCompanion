import 'dart:math' as math;

import 'dogma_modifier.dart';

/// Targeting + navigation stats for the ship — the rest of the
/// in-game fitting numbers that don't fit Resources / Defense /
/// Capacitor. Pilot modifiers (skills, implants) are applied through
/// the same modifier graph as the other panels.
class FitMisc {
  const FitMisc({
    required this.targetingRangeKm,
    required this.maxLockedTargets,
    required this.scanResolutionMm,
    required this.signatureRadius,
    required this.sensorStrength,
    required this.maxVelocity,
    required this.warpSpeed,
    required this.alignTimeSeconds,
  });

  final double targetingRangeKm;
  final int maxLockedTargets;
  final double scanResolutionMm;
  final double signatureRadius;
  final double sensorStrength;
  final double maxVelocity;
  final double warpSpeed;
  final double alignTimeSeconds;
}

class _A {
  // Target / sensors
  static const maxTargetRange = 76; // metres → km
  static const maxLockedTargets = 192;
  static const scanResolution = 564; // mm
  static const signatureRadius = 552;
  static const gravimetric = 208;
  static const ladar = 209;
  static const magnetometric = 210;
  static const radar = 211;

  // Movement
  static const maxVelocity = 37; // m/s
  static const warpSpeedMultiplier = 600; // au/s
  static const agility = 70;
  static const mass = 4;
}

FitMisc computeFitMisc({
  required Map<int, double> shipAttrs,
  Map<int, List<Modifier>> pilotMods = const {},
}) {
  double resolve(int attrId, [double fallback = 0]) {
    final base = shipAttrs[attrId] ?? fallback;
    final mods = pilotMods[attrId];
    if (mods == null || mods.isEmpty) return base;
    return resolveAttribute(base, mods);
  }

  // EVE convention: align time t = -ln(0.25) × mass × agility / 1e6.
  // Mass is kilograms, agility is unitless.
  final mass = resolve(_A.mass);
  final agility = resolve(_A.agility);
  final alignTime = mass <= 0 || agility <= 0
      ? 0.0
      : -math.log(0.25) * mass * agility / 1e6;

  // Sensor strength: a ship has only one of the four; report whichever
  // is non-zero.
  final sensors = [
    resolve(_A.gravimetric),
    resolve(_A.ladar),
    resolve(_A.magnetometric),
    resolve(_A.radar),
  ];
  final sensorStrength = sensors.fold<double>(0, math.max);

  return FitMisc(
    targetingRangeKm: resolve(_A.maxTargetRange) / 1000.0,
    maxLockedTargets: resolve(_A.maxLockedTargets).round(),
    scanResolutionMm: resolve(_A.scanResolution),
    signatureRadius: resolve(_A.signatureRadius),
    sensorStrength: sensorStrength,
    maxVelocity: resolve(_A.maxVelocity),
    warpSpeed: resolve(_A.warpSpeedMultiplier),
    alignTimeSeconds: alignTime,
  );
}
