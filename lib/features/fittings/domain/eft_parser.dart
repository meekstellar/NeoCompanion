import 'dart:convert';

import 'slot_grouping.dart';

class ParsedFittingItem {
  const ParsedFittingItem({
    required this.name,
    required this.quantity,
    required this.slot,
  });

  final String name;
  final int quantity;
  final FittingSlot slot;
}

class ParsedFitting {
  const ParsedFitting({
    required this.shipName,
    required this.fitName,
    required this.items,
  });

  final String shipName;
  final String fitName;
  final List<ParsedFittingItem> items;
}

class EftParseException implements Exception {
  EftParseException(this.message);
  final String message;
  @override
  String toString() => 'EftParseException: $message';
}

/// Parses EFT-format text into a [ParsedFitting].
///
/// Expected layout:
///
///     [ShipName, FitName]
///     <module-group-1>     // Low slots
///                          // blank line
///     <module-group-2>     // Mid slots
///                          // blank line
///     <module-group-3>     // High slots
///                          // ... rigs, subsystems, drones (xN), cargo (xN)
///
/// Module groups are assigned slots in canonical EFT order (low → mid →
/// high → rigs → subsystem). Groups whose lines all carry an `xN` suffix
/// are treated as drone bay (first such group) or cargo (subsequent).
/// `[Empty * slot]` placeholders inside a module group are skipped but
/// the group still counts toward the slot order so empty slots don't
/// shift the assignment.
ParsedFitting parseEft(String input) {
  final lines = const LineSplitter().convert(input);

  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  if (i >= lines.length) {
    throw EftParseException('Empty input');
  }

  final headerMatch =
      RegExp(r'^\[(.+?),\s*(.+)\]$').firstMatch(lines[i].trim());
  if (headerMatch == null) {
    throw EftParseException(
      "Header missing — expected '[ShipName, FitName]' on the first line",
    );
  }
  final shipName = headerMatch.group(1)!.trim();
  final fitName = headerMatch.group(2)!.trim();
  i++;

  // Split remaining lines into groups separated by blank lines.
  final groups = <List<String>>[];
  var current = <String>[];
  for (; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      if (current.isNotEmpty) {
        groups.add(current);
        current = [];
      }
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) groups.add(current);

  // Strip [Empty * slot] placeholders from each group.
  final emptyPlaceholder = RegExp(r'^\[Empty .* slot\]$', caseSensitive: false);
  final cleaned = groups
      .map((g) => g.where((l) => !emptyPlaceholder.hasMatch(l)).toList())
      .toList();

  const moduleSlots = [
    FittingSlot.lowSlot,
    FittingSlot.medSlot,
    FittingSlot.highSlot,
    FittingSlot.rigSlot,
    FittingSlot.subsystem,
  ];

  final qtySuffix = RegExp(r' x(\d+)$');

  final items = <ParsedFittingItem>[];
  var moduleIdx = 0;
  var quantityGroups = 0;

  for (final group in cleaned) {
    if (group.isEmpty) {
      moduleIdx++;
      continue;
    }
    final allHaveQty = group.every((l) => qtySuffix.hasMatch(l));
    if (allHaveQty) {
      final slot =
          quantityGroups == 0 ? FittingSlot.drone : FittingSlot.cargo;
      quantityGroups++;
      for (final line in group) {
        final m = qtySuffix.firstMatch(line)!;
        final name = line.substring(0, m.start).trim();
        final qty = int.parse(m.group(1)!);
        items.add(ParsedFittingItem(name: name, quantity: qty, slot: slot));
      }
    } else {
      if (moduleIdx >= moduleSlots.length) {
        throw EftParseException(
          'Too many module groups — got at least ${moduleIdx + 1}',
        );
      }
      final slot = moduleSlots[moduleIdx];
      moduleIdx++;
      for (final line in group) {
        items.add(ParsedFittingItem(name: line, quantity: 1, slot: slot));
      }
    }
  }

  if (items.isEmpty) {
    throw EftParseException('No items parsed');
  }

  return ParsedFitting(
    shipName: shipName,
    fitName: fitName,
    items: items,
  );
}
