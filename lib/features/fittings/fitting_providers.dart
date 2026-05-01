import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/types/types_database.dart';
import '../../core/types/types_database_providers.dart';
import '../clones/clones_providers.dart';
import '../skills/skill_providers.dart';
import 'data/dto/fitting.dart';
import 'data/fitting_repository.dart';
import 'domain/dogma_modifier.dart';
import 'domain/fit_capacitor.dart';
import 'domain/fit_defense.dart';
import 'domain/fit_misc.dart';
import 'domain/fit_resources.dart';

/// Reads dogma attributes / effects / volumes for [shipTypeId] and every
/// distinct item type, then runs the resource computation. [pilotMods]
/// is the precomputed ship-attribute modifier graph from the active
/// character's skills + implants — pass an empty map for a pilot-less
/// view (base SDE numbers).
Future<FitResources> loadFitResources({
  required TypesDatabase db,
  required int shipTypeId,
  required List<FittingItem> items,
  Map<int, int> skills = const {},
  Map<int, List<Modifier>> pilotMods = const {},
}) async {
  final shipAttrs = Map<int, double>.from(
    await db.typeDogmaAttributes(shipTypeId),
  );
  // CCP keeps the ship's cargo bay on `invTypes.capacity`, not as a
  // dogma attribute — without this fallback the resources panel and
  // the cargo card would think the ship has no cargo at all.
  if (!shipAttrs.containsKey(38)) {
    final cap = await db.typeCapacity(shipTypeId);
    if (cap != null && cap > 0) shipAttrs[38] = cap;
  }
  final attrsByType = <int, Map<int, double>>{};
  final effectsByType = <int, Set<int>>{};
  for (final item in items) {
    if (attrsByType.containsKey(item.typeId)) continue;
    attrsByType[item.typeId] = await db.typeDogmaAttributes(item.typeId);
    effectsByType[item.typeId] = await db.typeDogmaEffectIds(item.typeId);
  }
  final volumesByType = await db.typeVolumes(items.map((i) => i.typeId));
  return computeFitResources(
    shipAttrs: shipAttrs,
    items: items,
    attrsByType: attrsByType,
    effectsByType: effectsByType,
    volumesByType: volumesByType,
    skills: skills,
    pilotMods: pilotMods,
  );
}

/// Defense view (HP + resists per damage type + EHP) for the fit.
/// Walks the fitted modules looking for known resist-modifier source
/// attributes (`armorEmDamageResonanceMultiplier` etc.), applies them
/// as `postMul` modifiers to the ship's resonance attributes through
/// the dogma framework, with stacking penalty when the source attr
/// is non-stackable in the SDE.
Future<FitDefense> loadFitDefense({
  required TypesDatabase db,
  required int shipTypeId,
  required List<FittingItem> items,
}) async {
  final shipAttrs = await db.typeDogmaAttributes(shipTypeId);
  final attrsByType = <int, Map<int, double>>{};
  for (final item in items) {
    if (attrsByType.containsKey(item.typeId)) continue;
    attrsByType[item.typeId] = await db.typeDogmaAttributes(item.typeId);
  }
  final ids = DefenseAttrIds.resolve(db);
  return computeFitDefense(
    shipAttrs: shipAttrs,
    items: items,
    attrsByType: attrsByType,
    ids: ids,
  );
}

/// Capacitor view: capacity, recharge, total active-module drain, and
/// stability. [pilotMods] applies skills/implants (e.g. capacitor
/// management → faster recharge, capacitor capacity bonus → bigger
/// pool) through the dogma framework.
Future<FitCapacitor> loadFitCapacitor({
  required TypesDatabase db,
  required int shipTypeId,
  required List<FittingItem> items,
  Map<int, List<Modifier>> pilotMods = const {},
}) async {
  final shipAttrs = await db.typeDogmaAttributes(shipTypeId);
  final attrsByType = <int, Map<int, double>>{};
  for (final item in items) {
    if (attrsByType.containsKey(item.typeId)) continue;
    attrsByType[item.typeId] = await db.typeDogmaAttributes(item.typeId);
  }
  final ids = CapacitorAttrIds.resolve(db.attributeIdByName);
  return computeFitCapacitor(
    shipAttrs: shipAttrs,
    items: items,
    attrsByType: attrsByType,
    ids: ids,
    pilotMods: pilotMods,
  );
}

/// Skills that contribute ship-side `postPercent` modifiers — the ones
/// that don't already need to be applied per module (those stay as
/// raw level lookups in [computeFitResources]).
const Map<int, ({String target, double pctPerLvl, int fallbackTargetId})>
    _shipSkillBonuses = {
  // CPU Management → cpuOutput +5%/lvl
  3426: (target: 'cpuOutput', pctPerLvl: 5.0, fallbackTargetId: 48),
  // Power Grid Management → powerOutput +5%/lvl
  3413: (target: 'powerOutput', pctPerLvl: 5.0, fallbackTargetId: 11),
  // Capacitor Management → capacitorCapacity +5%/lvl
  3418: (target: 'capacitorCapacity', pctPerLvl: 5.0, fallbackTargetId: 482),
  // Capacitor Systems Operation → rechargeRate −5%/lvl
  3417: (target: 'rechargeRate', pctPerLvl: -5.0, fallbackTargetId: 55),
};

/// Implant attribute names → ship attribute they modify (postPercent).
/// We rely on the canonical SDE name lookup; implants whose modifier
/// source attribute isn't in this map silently skip — same fail-safe
/// as the resist modifier path.
const Map<String, String> _implantSourceToTarget = {
  'cpuOutputBonus2': 'cpuOutput',
  'cpuOutputBonus': 'cpuOutput',
  'powerOutputBonus2': 'powerOutput',
  'powerOutputBonus': 'powerOutput',
  'capacitorCapacityBonus': 'capacitorCapacity',
  'capacitorCapacityMultiplier': 'capacitorCapacity',
  'capRechargeBonus': 'rechargeRate',
};

/// Modifier graph (`shipAttributeId → modifiers`) from the active
/// character's skills + slotted implants. Both contribute as stackable
/// post-percent modifiers — the in-game stacking penalty only applies
/// between modules of the same kind, not between pilot bonuses and
/// modules.
final pilotShipModifiersProvider = FutureProvider.family<
    Map<int, List<Modifier>>, int>((ref, characterId) async {
  final db = ref.watch(typesDatabaseProvider);
  final out = <int, List<Modifier>>{};

  // 1. Skills.
  final skills =
      await ref.watch(characterSkillLevelsProvider(characterId).future);
  for (final entry in _shipSkillBonuses.entries) {
    final lvl = skills[entry.key] ?? 0;
    if (lvl <= 0) continue;
    final spec = entry.value;
    final targetId = db.attributeIdByName(spec.target) ?? spec.fallbackTargetId;
    out.putIfAbsent(targetId, () => []).add(Modifier(
          op: ModifierOp.postPercent,
          value: spec.pctPerLvl * lvl,
          source: 'skill-${entry.key}',
          stackable: true,
        ));
  }

  // 2. Implants. Only kicks in once `dogma_attributes.name` is
  //    populated — silently no-ops on older SDE imports.
  try {
    final implants =
        await ref.watch(activeImplantsProvider(characterId).future);
    for (final pair in _implantSourceToTarget.entries) {
      final sourceId = db.attributeIdByName(pair.key);
      final targetId = db.attributeIdByName(pair.value);
      if (sourceId == null || targetId == null) continue;
      for (final implantId in implants) {
        final attrs = await db.typeDogmaAttributes(implantId);
        final v = attrs[sourceId];
        if (v == null) continue;
        out.putIfAbsent(targetId, () => []).add(Modifier(
              op: ModifierOp.postPercent,
              value: v,
              source: 'implant-$implantId',
              stackable: true,
            ));
      }
    }
  } catch (_) {
    // Network/unauth errors are fine — implants just don't apply.
  }

  return out;
});

/// Targeting + navigation stats. Pure ship attributes today; pilot
/// mods only apply to the few attrs we route through the dogma graph
/// (currently just CPU/PG/cap — adding speed/agility/scan res to that
/// graph is part of the broader skill bonus rollout).
Future<FitMisc> loadFitMisc({
  required TypesDatabase db,
  required int shipTypeId,
  Map<int, List<Modifier>> pilotMods = const {},
}) async {
  final shipAttrs = await db.typeDogmaAttributes(shipTypeId);
  return computeFitMisc(shipAttrs: shipAttrs, pilotMods: pilotMods);
}

/// Maps a character's active skills to `(skillTypeId → level)`. Returns
/// an empty map on failure or for characters whose skills aren't loaded
/// yet — the fitting compute treats absent skills as level 0, so the
/// numbers degrade gracefully into the unboosted baseline.
final characterSkillLevelsProvider =
    FutureProvider.family<Map<int, int>, int>((ref, characterId) async {
  try {
    final data = await ref.watch(allSkillsProvider(characterId).future);
    return {
      for (final s in data.skills.skills) s.skillId: s.activeSkillLevel,
    };
  } catch (_) {
    return const {};
  }
});

final fittingRepositoryProvider = Provider<FittingRepository>((ref) {
  return FittingRepository(ref.watch(esiClientProvider));
});

class FittingsData {
  const FittingsData({required this.fittings, required this.typeNames});

  final List<Fitting> fittings;
  final Map<int, String> typeNames;
}

final fittingsProvider =
    FutureProvider.family<FittingsData, int>((ref, characterId) async {
  ref.watch(typesDatabaseRevisionProvider);
  final repo = ref.watch(fittingRepositoryProvider);
  final typesDb = ref.watch(typesDatabaseProvider);

  final fittings = await repo.fetchAll(characterId);

  final names = <int, String>{};
  for (final f in fittings) {
    final ship = typesDb.lookup(f.shipTypeId);
    if (ship != null) names[f.shipTypeId] = ship;
    for (final i in f.items) {
      final n = typesDb.lookup(i.typeId);
      if (n != null) names[i.typeId] = n;
    }
  }

  return FittingsData(fittings: fittings, typeNames: names);
});

/// Resolves a fit's CPU / PG / calibration / slot usage by reading dogma
/// attributes from the local SDE. Stage 1 — no skills, no stacking
/// penalties; just sums of base values.
final fitResourcesProvider = FutureProvider.autoDispose
    .family<FitResources, ({int characterId, int fittingId})>(
        (ref, args) async {
  ref.watch(typesDatabaseRevisionProvider);
  final data = await ref.watch(fittingsProvider(args.characterId).future);
  final fit =
      data.fittings.where((f) => f.fittingId == args.fittingId).firstOrNull;
  if (fit == null) {
    throw StateError('Fitting #${args.fittingId} not found');
  }
  final db = ref.watch(typesDatabaseProvider);
  final skills =
      await ref.watch(characterSkillLevelsProvider(args.characterId).future);
  return loadFitResources(
    db: db,
    shipTypeId: fit.shipTypeId,
    items: fit.items,
    skills: skills,
  );
});
