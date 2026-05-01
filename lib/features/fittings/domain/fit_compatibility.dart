import '../../../core/types/types_database.dart';
import '../data/dto/fitting.dart';
import 'slot_grouping.dart';

/// One reason a module can't (cleanly) fit on the ship.
class FitConflict {
  const FitConflict(this.message);
  final String message;
}

/// Hardcoded fallback for when the SDE name column hasn't been
/// re-imported yet — covers the well-known core ids shipped in every
/// SDE build. Once the importer surfaces canonical names, the
/// discovery path takes over and this list is ignored.
const _fallbackCanFitGroupIds = <int>[
  1298, 1299, 1300, 1301,
  1872, 1879, 1880, 1881, 2065,
  2396, 2397, 2398, 2399, 2400, 2401, 2402, 2403, 2404, 2405, 2406,
];
const _fallbackCanFitTypeIds = <int>[
  1308, 1309, 1310, 1311, 1312, 1389, 1390, 2227,
];

const int _maxGroupFittedAttr = 1544;
const int _rigSizeAttr = 1547;

/// Checks the picked module against the ship for the in-game
/// allow-lists, rig-size match, and the "max N of this group" cap.
/// Returns the list of conflicts, empty if the module is compatible.
///
/// We deliberately don't flag plain CPU / power-grid over-budget here
/// — the resources panel already shows the bars in red, and the user
/// might be planning a fit that gets there with skills. This dialog
/// is for *rule* incompatibility, not just "you're over budget right
/// now".
Future<List<FitConflict>> validateModuleFit({
  required TypesDatabase db,
  required int moduleTypeId,
  required int shipTypeId,
  required FittingSlot slot,
  required List<FittingItem> currentItems,
}) async {
  final mAttrs = await db.typeDogmaAttributes(moduleTypeId);
  final sAttrs = await db.typeDogmaAttributes(shipTypeId);
  final shipGroupId = db.typeGroupId(shipTypeId);
  final issues = <FitConflict>[];

  // canFitShipGroup* — discover attribute ids by canonical name when
  // the SDE has it, fall back to the well-known core ids otherwise.
  final canFitGroupAttrs = () {
    final discovered = db.attributeIdsByNamePrefix('canFitShipGroup');
    return discovered.isEmpty ? _fallbackCanFitGroupIds : discovered;
  }();
  final allowedGroups = [
    for (final a in canFitGroupAttrs)
      if (mAttrs[a] != null) mAttrs[a]!.toInt(),
  ];
  if (allowedGroups.isNotEmpty &&
      shipGroupId != null &&
      !allowedGroups.contains(shipGroupId)) {
    final names = allowedGroups
        .map((g) => db.lookupGroup(g) ?? '#$g')
        .join(', ');
    issues.add(FitConflict('Restricted to: $names.'));
  }

  // canFitShipType* — same pattern, keyed on a specific ship type id.
  final canFitTypeAttrs = () {
    final discovered = db.attributeIdsByNamePrefix('canFitShipType');
    return discovered.isEmpty ? _fallbackCanFitTypeIds : discovered;
  }();
  final allowedTypes = [
    for (final a in canFitTypeAttrs)
      if (mAttrs[a] != null) mAttrs[a]!.toInt(),
  ];
  if (allowedTypes.isNotEmpty && !allowedTypes.contains(shipTypeId)) {
    final names =
        allowedTypes.map((t) => db.lookup(t) ?? '#$t').join(', ');
    issues.add(FitConflict('Restricted to: $names.'));
  }

  // Rig size mismatch — only meaningful for the rig slot.
  if (slot == FittingSlot.rigSlot) {
    final mRigSize = mAttrs[_rigSizeAttr]?.toInt();
    final sRigSize = sAttrs[_rigSizeAttr]?.toInt();
    if (mRigSize != null && sRigSize != null && mRigSize != sRigSize) {
      const names = {1: 'Small', 2: 'Medium', 3: 'Large', 4: 'X-Large'};
      final m = names[mRigSize] ?? 'Size $mRigSize';
      final s = names[sRigSize] ?? 'Size $sRigSize';
      issues.add(FitConflict('Rig is $m; ship takes $s rigs.'));
    }
  }

  // maxGroupFitted — some modules cap how many of their group can be
  // fitted at once (e.g. 1× Damage Control). Counts items already on
  // the fit that share the candidate's group_id.
  final maxPerGroup = mAttrs[_maxGroupFittedAttr]?.toInt();
  if (maxPerGroup != null && maxPerGroup > 0) {
    final candidateGroupId = db.typeGroupId(moduleTypeId);
    if (candidateGroupId != null) {
      final fittedSameGroup = currentItems.where((it) {
        final g = db.typeGroupId(it.typeId);
        return g == candidateGroupId;
      }).length;
      if (fittedSameGroup >= maxPerGroup) {
        final groupName = db.lookupGroup(candidateGroupId) ?? 'this type';
        issues.add(FitConflict(
          'Only $maxPerGroup × $groupName allowed per ship.',
        ));
      }
    }
  }

  return issues;
}
