import 'dart:math' as math;

import '../data/dto/fitting.dart';
import 'dogma_modifier.dart';

/// Cap recharge follows EVE's standard differential equation:
///   dC/dt = (10 / τ) * (sqrt(C/Cmax) - C/Cmax) * Cmax
/// where τ is `rechargeRate` in seconds. Peak rate is at 25% capacitor
/// (`sqrt(0.25) - 0.25 = 0.25`), giving `2.5 * Cmax / τ`.
class FitCapacitor {
  const FitCapacitor({
    required this.capacity,
    required this.rechargeSeconds,
    required this.peakRechargePerSec,
    required this.drainPerSec,
    required this.stable,
    this.stablePercent,
    this.secondsToEmpty,
  });

  final double capacity;
  final double rechargeSeconds;
  final double peakRechargePerSec;
  final double drainPerSec;

  /// True iff total drain ≤ peak recharge (a stable equilibrium exists
  /// somewhere in `0 < C/Cmax ≤ 25%`). When false, the fit will run
  /// out of cap; [secondsToEmpty] estimates how fast.
  final bool stable;

  /// Equilibrium capacitor as a fraction of [capacity], when [stable].
  final double? stablePercent;

  /// Estimated time from full cap to empty, when not [stable]. Computed
  /// by Euler integration with 0.5s steps; close enough for UI.
  final double? secondsToEmpty;

  /// Convenience: total cycle drain minus what passive recharge can
  /// sustain. Positive ⇒ cap is leaking, negative ⇒ headroom.
  double get netDrainPerSec => drainPerSec - peakRechargePerSec;
}

/// SDE attribute ids the cap math needs. Hardcoded numeric fallbacks
/// kick in until the importer surfaces canonical names.
class CapacitorAttrIds {
  CapacitorAttrIds._({
    required this.capacity,
    required this.rechargeRate,
    required this.capacitorNeed,
    required this.duration,
  });

  factory CapacitorAttrIds.resolve(int? Function(String) byName) {
    int id(String name, int fallback) => byName(name) ?? fallback;
    return CapacitorAttrIds._(
      capacity: id('capacitorCapacity', 482),
      rechargeRate: id('rechargeRate', 55),
      capacitorNeed: id('capacitorNeed', 6),
      duration: id('duration', 73),
    );
  }

  final int capacity;
  final int rechargeRate;
  final int capacitorNeed;
  final int duration;
}

FitCapacitor computeFitCapacitor({
  required Map<int, double> shipAttrs,
  required List<FittingItem> items,
  required Map<int, Map<int, double>> attrsByType,
  required CapacitorAttrIds ids,
  Map<int, List<Modifier>> pilotMods = const {},
}) {
  double resolveShip(int attrId) {
    final base = shipAttrs[attrId] ?? 0;
    final mods = pilotMods[attrId];
    if (mods == null || mods.isEmpty) return base;
    return resolveAttribute(base, mods);
  }

  final capacity = resolveShip(ids.capacity);
  final rechargeMs = resolveShip(ids.rechargeRate);
  final rechargeSeconds = rechargeMs / 1000.0;

  // Peak passive recharge (units / second) at 25% capacitor.
  final peakRecharge =
      rechargeSeconds <= 0 ? 0.0 : 2.5 * capacity / rechargeSeconds;

  // Sum module drain. A module drains cap when it carries both
  // `capacitorNeed > 0` and a `duration > 0`. Passive modules and
  // one-shot online costs fall out naturally (no duration).
  double drain = 0;
  for (final item in items) {
    final attrs = attrsByType[item.typeId] ?? const <int, double>{};
    final need = attrs[ids.capacitorNeed] ?? 0;
    final dur = attrs[ids.duration] ?? 0;
    if (need <= 0 || dur <= 0) continue;
    drain += (need / (dur / 1000.0)) * item.quantity;
  }

  // Stability check: solve `2.5x' - x = D*τ/(10*Cmax)` where
  // x' = sqrt(x) and x = C/Cmax. Real root exists iff D ≤ peak.
  bool stable = false;
  double? stablePercent;
  double? secondsToEmpty;
  if (rechargeSeconds > 0 && capacity > 0) {
    if (drain <= peakRecharge) {
      stable = true;
      final k = drain * rechargeSeconds / (10.0 * capacity);
      // y² - y + k = 0  →  y = (1 + sqrt(1 - 4k)) / 2  (larger root)
      final disc = 1.0 - 4.0 * k;
      final y = disc < 0 ? 0.5 : (1.0 + math.sqrt(disc)) / 2.0;
      stablePercent = y * y;
    } else {
      // Numerically integrate from full to empty using Euler steps.
      var c = capacity;
      var t = 0.0;
      const dt = 0.5;
      const cap = 7200.0; // 2 hours; if it lasts that long we round.
      while (c > 0 && t < cap) {
        final ratio = c / capacity;
        final recharge =
            (10.0 / rechargeSeconds) * (math.sqrt(ratio) - ratio) * capacity;
        final net = drain - recharge;
        if (net <= 0) break;
        c -= net * dt;
        t += dt;
      }
      secondsToEmpty = t;
    }
  }

  return FitCapacitor(
    capacity: capacity,
    rechargeSeconds: rechargeSeconds,
    peakRechargePerSec: peakRecharge,
    drainPerSec: drain,
    stable: stable,
    stablePercent: stablePercent,
    secondsToEmpty: secondsToEmpty,
  );
}
