import '../../../core/types/types_database.dart';
import '../data/dto/fitting.dart';
import 'dogma_modifier.dart';

/// Damage type weights summing to 1.0. Drives the EHP weighting —
/// "omni" is uniform 0.25 each, but PvP fits often optimise against
/// a specific damage profile (e.g. Sansha = 50% EM / 50% Thermal).
class DamageProfile {
  const DamageProfile({
    required this.em,
    required this.thermal,
    required this.kinetic,
    required this.explosive,
  });

  final double em;
  final double thermal;
  final double kinetic;
  final double explosive;

  static const omni = DamageProfile(
    em: 0.25,
    thermal: 0.25,
    kinetic: 0.25,
    explosive: 0.25,
  );
}

/// Damage resonances (0..1) for one layer of the ship — the multiplier
/// applied to incoming damage. Resist percent shown to the user is
/// `(1 - resonance) * 100`.
class LayerResonances {
  const LayerResonances({
    required this.em,
    required this.thermal,
    required this.kinetic,
    required this.explosive,
  });

  final double em;
  final double thermal;
  final double kinetic;
  final double explosive;

  /// Damage-profile-weighted resonance — used as the EHP divisor.
  double weighted(DamageProfile profile) {
    return em * profile.em +
        thermal * profile.thermal +
        kinetic * profile.kinetic +
        explosive * profile.explosive;
  }
}

class DefenseLayer {
  const DefenseLayer({required this.hp, required this.resonances});

  final double hp;
  final LayerResonances resonances;

  double ehp(DamageProfile profile) {
    final r = resonances.weighted(profile);
    if (r <= 0) return hp;
    return hp / r;
  }
}

class FitDefense {
  const FitDefense({
    required this.shield,
    required this.armor,
    required this.hull,
  });

  final DefenseLayer shield;
  final DefenseLayer armor;
  final DefenseLayer hull;

  double totalEhp(DamageProfile profile) {
    return shield.ehp(profile) + armor.ehp(profile) + hull.ehp(profile);
  }
}

/// Canonical SDE attribute names that the defense compute needs to
/// resolve to numeric ids. Hardcoded numeric fallbacks shipped here
/// are best-effort guesses from EVE community references — they're
/// only used if the SDE name → id map hasn't been populated yet
/// (i.e. before a re-import lands the new schema column).
class _A {
  static const shieldHp = ('shieldCapacity', 263);
  static const armorHp = ('armorHP', 265);
  static const hullHp = ('hp', 9);

  static const shieldEm = ('shieldEmDamageResonance', 271);
  static const shieldThermal = ('shieldThermalDamageResonance', 274);
  static const shieldKinetic = ('shieldKineticDamageResonance', 273);
  static const shieldExplosive = ('shieldExplosiveDamageResonance', 272);

  static const armorEm = ('armorEmDamageResonance', 267);
  static const armorThermal = ('armorThermalDamageResonance', 270);
  static const armorKinetic = ('armorKineticDamageResonance', 269);
  static const armorExplosive = ('armorExplosiveDamageResonance', 268);

  static const hullEm = ('emDamageResonance', 113);
  static const hullThermal = ('thermalDamageResonance', 116);
  static const hullKinetic = ('kineticDamageResonance', 115);
  static const hullExplosive = ('explosiveDamageResonance', 114);
}

/// Module attribute names → ship resonance attribute names. When a
/// fitted module has the source attribute, its value is applied as a
/// `postMul` modifier to the corresponding ship resonance, with the
/// stacking penalty determined by the source attribute's `stackable`
/// flag in the SDE.
const Map<String, String> _resistSourceToTarget = {
  'armorEmDamageResonanceMultiplier': 'armorEmDamageResonance',
  'armorThermalDamageResonanceMultiplier': 'armorThermalDamageResonance',
  'armorKineticDamageResonanceMultiplier': 'armorKineticDamageResonance',
  'armorExplosiveDamageResonanceMultiplier': 'armorExplosiveDamageResonance',
  'shieldEmDamageResonanceMultiplier': 'shieldEmDamageResonance',
  'shieldThermalDamageResonanceMultiplier': 'shieldThermalDamageResonance',
  'shieldKineticDamageResonanceMultiplier': 'shieldKineticDamageResonance',
  'shieldExplosiveDamageResonanceMultiplier': 'shieldExplosiveDamageResonance',
};

/// Resolves the SDE attribute ids the compute relies on, building maps
/// of "source attr id → target ship attr id" and per-id stackable
/// flags from the canonical-name lookup. Falls back to hardcoded ids
/// when the SDE hasn't been re-imported yet (the `name` column is
/// new in schema v5).
class DefenseAttrIds {
  DefenseAttrIds._({
    required this.shieldHp,
    required this.armorHp,
    required this.hullHp,
    required this.shieldRes,
    required this.armorRes,
    required this.hullRes,
    required this.modifierMap,
    required this.stackable,
  });

  factory DefenseAttrIds.resolve(TypesDatabase db) {
    int id((String, int) pair) => db.attributeIdByName(pair.$1) ?? pair.$2;

    final modifierMap = <int, int>{};
    for (final entry in _resistSourceToTarget.entries) {
      final source = db.attributeIdByName(entry.key);
      final target = db.attributeIdByName(entry.value);
      if (source != null && target != null) {
        modifierMap[source] = target;
      }
    }

    final stackable = <int, bool>{};
    for (final src in modifierMap.keys) {
      stackable[src] = db.attributeIsStackable(src);
    }

    return DefenseAttrIds._(
      shieldHp: id(_A.shieldHp),
      armorHp: id(_A.armorHp),
      hullHp: id(_A.hullHp),
      shieldRes: (
        em: id(_A.shieldEm),
        thermal: id(_A.shieldThermal),
        kinetic: id(_A.shieldKinetic),
        explosive: id(_A.shieldExplosive),
      ),
      armorRes: (
        em: id(_A.armorEm),
        thermal: id(_A.armorThermal),
        kinetic: id(_A.armorKinetic),
        explosive: id(_A.armorExplosive),
      ),
      hullRes: (
        em: id(_A.hullEm),
        thermal: id(_A.hullThermal),
        kinetic: id(_A.hullKinetic),
        explosive: id(_A.hullExplosive),
      ),
      modifierMap: modifierMap,
      stackable: stackable,
    );
  }

  final int shieldHp;
  final int armorHp;
  final int hullHp;
  final ({int em, int thermal, int kinetic, int explosive}) shieldRes;
  final ({int em, int thermal, int kinetic, int explosive}) armorRes;
  final ({int em, int thermal, int kinetic, int explosive}) hullRes;

  /// `(modifier source attr id) → (target ship resonance attr id)`.
  final Map<int, int> modifierMap;

  /// Whether the modifier source attribute is exempt from the stacking
  /// penalty.
  final Map<int, bool> stackable;
}

FitDefense computeFitDefense({
  required Map<int, double> shipAttrs,
  required List<FittingItem> items,
  required Map<int, Map<int, double>> attrsByType,
  required DefenseAttrIds ids,
}) {
  // Bucket module modifiers by target ship attribute id.
  final modsByTarget = <int, List<Modifier>>{};
  for (final item in items) {
    final attrs = attrsByType[item.typeId] ?? const <int, double>{};
    for (final entry in attrs.entries) {
      final target = ids.modifierMap[entry.key];
      if (target == null) continue;
      modsByTarget.putIfAbsent(target, () => []).add(Modifier(
            op: ModifierOp.postMul,
            value: entry.value,
            source: 'item-${item.typeId}-${item.flag}',
            stackable: ids.stackable[entry.key] ?? false,
          ));
    }
  }

  double resolve(int attrId, double fallback) {
    final base = shipAttrs[attrId] ?? fallback;
    final mods = modsByTarget[attrId];
    if (mods == null || mods.isEmpty) return base;
    return resolveAttribute(base, mods);
  }

  return FitDefense(
    shield: DefenseLayer(
      hp: shipAttrs[ids.shieldHp] ?? 0,
      resonances: LayerResonances(
        em: resolve(ids.shieldRes.em, 1.0),
        thermal: resolve(ids.shieldRes.thermal, 1.0),
        kinetic: resolve(ids.shieldRes.kinetic, 1.0),
        explosive: resolve(ids.shieldRes.explosive, 1.0),
      ),
    ),
    armor: DefenseLayer(
      hp: shipAttrs[ids.armorHp] ?? 0,
      resonances: LayerResonances(
        em: resolve(ids.armorRes.em, 1.0),
        thermal: resolve(ids.armorRes.thermal, 1.0),
        kinetic: resolve(ids.armorRes.kinetic, 1.0),
        explosive: resolve(ids.armorRes.explosive, 1.0),
      ),
    ),
    hull: DefenseLayer(
      hp: shipAttrs[ids.hullHp] ?? 0,
      resonances: LayerResonances(
        em: resolve(ids.hullRes.em, 1.0),
        thermal: resolve(ids.hullRes.thermal, 1.0),
        kinetic: resolve(ids.hullRes.kinetic, 1.0),
        explosive: resolve(ids.hullRes.explosive, 1.0),
      ),
    ),
  );
}
