import 'eft_parser.dart';
import 'slot_grouping.dart';

class FittingPayload {
  const FittingPayload({
    required this.name,
    required this.description,
    required this.shipTypeId,
    required this.items,
    required this.unresolvedNames,
  });

  final String name;
  final String description;
  final int shipTypeId;
  final List<FittingPayloadItem> items;
  final List<String> unresolvedNames;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'ship_type_id': shipTypeId,
        'items': [for (final i in items) i.toJson()],
      };
}

class FittingPayloadItem {
  const FittingPayloadItem({
    required this.flag,
    required this.quantity,
    required this.typeId,
  });

  final String flag;
  final int quantity;
  final int typeId;

  Map<String, dynamic> toJson() => {
        'flag': flag,
        'quantity': quantity,
        'type_id': typeId,
      };
}

/// Combines parser output with resolved name → id lookups into the JSON
/// payload ESI's POST /characters/{id}/fittings/ expects. Items whose
/// names can't be resolved go into [FittingPayload.unresolvedNames] so
/// the UI can warn before submitting.
FittingPayload toPayload(ParsedFitting parsed, Map<String, int> nameToId) {
  final shipId = nameToId[parsed.shipName];
  if (shipId == null) {
    throw StateError('Ship type "${parsed.shipName}" did not resolve');
  }

  final perSlotCounter = <FittingSlot, int>{};
  final items = <FittingPayloadItem>[];
  final unresolved = <String>[];

  for (final p in parsed.items) {
    final id = nameToId[p.name];
    if (id == null) {
      unresolved.add(p.name);
      continue;
    }
    final flag = _flagFor(p.slot, perSlotCounter);
    items.add(
      FittingPayloadItem(flag: flag, quantity: p.quantity, typeId: id),
    );
  }

  return FittingPayload(
    name: parsed.fitName,
    description: '',
    shipTypeId: shipId,
    items: items,
    unresolvedNames: unresolved,
  );
}

String _flagFor(FittingSlot slot, Map<FittingSlot, int> counter) {
  switch (slot) {
    case FittingSlot.highSlot:
      return 'HiSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.medSlot:
      return 'MedSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.lowSlot:
      return 'LoSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.rigSlot:
      return 'RigSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.subsystem:
      return 'SubSystemSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.service:
      return 'ServiceSlot${counter[slot] = (counter[slot] ?? -1) + 1}';
    case FittingSlot.drone:
      return 'DroneBay';
    case FittingSlot.fighter:
      return 'FighterBay';
    case FittingSlot.cargo:
      return 'Cargo';
    case FittingSlot.other:
      return 'Cargo';
  }
}
