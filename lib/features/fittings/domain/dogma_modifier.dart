import 'dart:math' as math;

/// Dogma modifier operations, applied to a target attribute in this
/// order: pre-assignment → pre-mul/div → mod-add/sub → post-mul/div →
/// post-percent → post-assignment. The stacking penalty (Pyfa /
/// Eos / EVE convention) only applies to multiplicative ops
/// (`preMul`, `postMul`, `postPercent`) and only for modifiers whose
/// source is *non-stackable*.
enum ModifierOp {
  preAssignment,
  preMul,
  preDiv,
  modAdd,
  modSub,
  postMul,
  postDiv,
  postPercent,
  postAssignment,
}

/// One modifier acting on a single target attribute.
///
/// [value]'s meaning depends on [op]:
///   - For `*Mul` / `*Div`: a raw multiplier (e.g. `1.05` = +5%).
///   - For `postPercent`: a percent (e.g. `5` = +5%).
///   - For `modAdd` / `modSub` / `*Assignment`: an absolute number.
///
/// [stackable] = true exempts the modifier from the stacking penalty.
/// In EVE, ship/skill/role/implant bonuses are stackable; module
/// effects of the same kind (e.g. multiple armor hardeners) are not.
class Modifier {
  const Modifier({
    required this.op,
    required this.value,
    required this.source,
    this.stackable = false,
  });

  final ModifierOp op;
  final double value;
  final String source;
  final bool stackable;

  @override
  String toString() =>
      'Modifier(${op.name}, $value, src=$source, stackable=$stackable)';
}

/// Applies [modifiers] to [base] and returns the resolved attribute.
/// Pure function — no I/O, no globals, easy to unit-test.
double resolveAttribute(double base, List<Modifier> modifiers) {
  final byOp = <ModifierOp, List<Modifier>>{};
  for (final m in modifiers) {
    byOp.putIfAbsent(m.op, () => []).add(m);
  }

  var value = base;

  // 1. Pre-assignment overrides the base.
  final preAssign = byOp[ModifierOp.preAssignment];
  if (preAssign != null && preAssign.isNotEmpty) {
    value = preAssign.last.value;
  }

  // 2. Pre-multiplicative (penalty-aware).
  value *= _stackedMul(byOp[ModifierOp.preMul]);
  value *= _stackedDiv(byOp[ModifierOp.preDiv]);

  // 3. Additive.
  for (final m in byOp[ModifierOp.modAdd] ?? const <Modifier>[]) {
    value += m.value;
  }
  for (final m in byOp[ModifierOp.modSub] ?? const <Modifier>[]) {
    value -= m.value;
  }

  // 4. Post-multiplicative.
  value *= _stackedMul(byOp[ModifierOp.postMul]);
  value *= _stackedDiv(byOp[ModifierOp.postDiv]);

  // 5. Post-percent. value here is treated as percent points, so
  //    `5` means "+5%" (multiplier 1.05). Negative values reduce.
  value *= _stackedPercent(byOp[ModifierOp.postPercent]);

  // 6. Post-assignment overrides everything.
  final postAssign = byOp[ModifierOp.postAssignment];
  if (postAssign != null && postAssign.isNotEmpty) {
    value = postAssign.last.value;
  }

  return value;
}

/// EVE's stacking penalty: the i-th non-stackable modifier (sorted by
/// effect magnitude, strongest first) is scaled by `exp(-(i/2.67)^2)`.
/// The first modifier applies at full strength.
double _stackingPenalty(int index) {
  return math.exp(-math.pow(index / 2.67, 2).toDouble());
}

double _stackedMul(List<Modifier>? mods) {
  if (mods == null || mods.isEmpty) return 1.0;
  final stackable = <double>[];
  final nonStackable = <double>[];
  for (final m in mods) {
    (m.stackable ? stackable : nonStackable).add(m.value);
  }
  var total = 1.0;
  for (final f in stackable) {
    total *= f;
  }
  // Sort by how far the multiplier deviates from 1.0 — strongest first.
  nonStackable.sort((a, b) => (b - 1.0).abs().compareTo((a - 1.0).abs()));
  for (var i = 0; i < nonStackable.length; i++) {
    final factor = nonStackable[i];
    total *= 1.0 + (factor - 1.0) * _stackingPenalty(i);
  }
  return total;
}

double _stackedDiv(List<Modifier>? mods) {
  if (mods == null || mods.isEmpty) return 1.0;
  // Reframe each divisor as a multiplier and reuse the mul logic.
  final inverted = [
    for (final m in mods)
      Modifier(
        op: ModifierOp.postMul,
        value: m.value == 0 ? 1.0 : 1.0 / m.value,
        source: m.source,
        stackable: m.stackable,
      ),
  ];
  return _stackedMul(inverted);
}

double _stackedPercent(List<Modifier>? mods) {
  if (mods == null || mods.isEmpty) return 1.0;
  final stackable = <double>[];
  final nonStackable = <double>[];
  for (final m in mods) {
    (m.stackable ? stackable : nonStackable).add(m.value);
  }
  var total = 1.0;
  for (final p in stackable) {
    total *= 1.0 + p / 100.0;
  }
  nonStackable.sort((a, b) => b.abs().compareTo(a.abs()));
  for (var i = 0; i < nonStackable.length; i++) {
    final p = nonStackable[i];
    total *= 1.0 + (p / 100.0) * _stackingPenalty(i);
  }
  return total;
}
