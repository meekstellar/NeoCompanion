import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import '../domain/slot_grouping.dart';
import 'market_group_tree.dart';

/// Result of [ModulePickerScreen]. `null` means the user cancelled
/// (back-tap), [ModulePicked] carries the chosen module, and
/// [ModuleRemoved] is the "unfit current module" action surfaced when
/// [ModulePickerScreen.fittedTypeId] is set.
sealed class ModulePickerResult {
  const ModulePickerResult();
}

class ModulePicked extends ModulePickerResult {
  const ModulePicked(this.typeId);
  final int typeId;
}

class ModuleRemoved extends ModulePickerResult {
  const ModuleRemoved();
}

/// Maps a fitting slot to the dogma effect id that marks a module as
/// fitting into that slot type. Returns null for slots that don't have
/// a single canonical effect (subsystem variants are race-specific,
/// drones/charges live in their own categories).
int? slotEffectId(FittingSlot slot) => switch (slot) {
      FittingSlot.highSlot => 12, // hiPower
      FittingSlot.medSlot => 13, // medPower
      FittingSlot.lowSlot => 11, // loPower
      FittingSlot.rigSlot => 2663, // rigSlot
      _ => null,
    };

/// Top-level market group root for a slot kind (the in-game market
/// browser scope). Hi/Med/Low all share "Modules"; Rigs and
/// Subsystems each have their own root.
int? _slotMarketRoot(FittingSlot slot) => switch (slot) {
      FittingSlot.highSlot ||
      FittingSlot.medSlot ||
      FittingSlot.lowSlot =>
        9, // Modules
      FittingSlot.rigSlot => 1111, // Rigs
      FittingSlot.subsystem => 1112, // Subsystems
      _ => null,
    };

/// Full-screen searchable picker for modules that fit a given [slot].
/// Pops back a [ModulePickerResult] (null on cancel). When
/// [fittedTypeId] is set, the picker renders a "Currently fitted"
/// header above the tree with a Remove action — tapping Remove pops
/// [ModuleRemoved], picking another module pops [ModulePicked].
class ModulePickerScreen extends ConsumerStatefulWidget {
  const ModulePickerScreen({
    super.key,
    required this.slot,
    this.fittedTypeId,
  });

  final FittingSlot slot;
  final int? fittedTypeId;

  @override
  ConsumerState<ModulePickerScreen> createState() =>
      _ModulePickerScreenState();
}

class _ModulePickerScreenState extends ConsumerState<ModulePickerScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectId = slotEffectId(widget.slot);
    return Scaffold(
      appBar: AppBar(title: Text('Pick ${widget.slot.title}')),
      body: effectId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Picking ${widget.slot.title} is not supported yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search modules',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(
                          const Duration(milliseconds: 200),
                          () => setState(() => _query = v));
                    },
                  ),
                ),
                Expanded(
                  child: _ResultsList(
                    effectId: effectId,
                    query: _query,
                    rootMarketGroupId: _slotMarketRoot(widget.slot),
                    fittedTypeId: widget.fittedTypeId,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({
    required this.effectId,
    required this.query,
    required this.rootMarketGroupId,
    required this.fittedTypeId,
  });

  final int effectId;
  final String query;
  final int? rootMarketGroupId;
  final int? fittedTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(typesDatabaseRevisionProvider);
    final db = ref.watch(typesDatabaseProvider);
    return FutureBuilder<List<TypeMatch>>(
      future: db.searchTypesByEffect(effectId: effectId, query: query),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snap.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        return MarketGroupTree(
          db: db,
          matches: results,
          rootMarketGroupId: rootMarketGroupId,
          autoExpand: query.trim().isNotEmpty,
          onPick: (id) => Navigator.of(context)
              .pop<ModulePickerResult>(ModulePicked(id)),
          leading: fittedTypeId == null
              ? null
              : _CurrentlyFitted(typeId: fittedTypeId!),
        );
      },
    );
  }
}

/// Header rendered at the top of the picker when the slot already has
/// a module — shows what's there and offers a quick Remove. Picking a
/// different module from the tree pops a [ModulePicked]; tapping
/// Remove pops [ModuleRemoved].
class _CurrentlyFitted extends ConsumerWidget {
  const _CurrentlyFitted({required this.typeId});

  final int typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(typesDatabaseProvider);
    final theme = Theme.of(context);
    final name = db.lookup(typeId) ?? '#$typeId';
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            EveTypeImage(
              typeId: typeId,
              size: 36,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currently fitted',
                    style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                          letterSpacing: 0.6,
                        ),
                  ),
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              iconSize: 24,
              padding: const EdgeInsets.all(12),
              onPressed: () => Navigator.of(context)
                  .pop<ModulePickerResult>(const ModuleRemoved()),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
