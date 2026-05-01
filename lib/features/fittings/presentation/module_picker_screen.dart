import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database.dart';
import '../../../core/types/types_database_providers.dart';
import '../domain/slot_grouping.dart';

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

/// Full-screen searchable picker for modules that fit a given [slot].
/// Pops back a [int] type id when the user picks something, or null on
/// cancel. When [shipTypeId] is provided, picks a Rig slot are filtered
/// by the ship's [rigSize] so the user can't fit, e.g. a Small rig on
/// a Cruiser.
class ModulePickerScreen extends ConsumerStatefulWidget {
  const ModulePickerScreen({
    super.key,
    required this.slot,
    this.shipTypeId,
  });

  final FittingSlot slot;
  final int? shipTypeId;

  @override
  ConsumerState<ModulePickerScreen> createState() =>
      _ModulePickerScreenState();
}

class _ModulePickerScreenState extends ConsumerState<ModulePickerScreen> {
  String _query = '';
  Timer? _debounce;
  int? _rigSizeFilter;
  bool _shipAttrsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadShipAttrs();
  }

  Future<void> _loadShipAttrs() async {
    final shipId = widget.shipTypeId;
    if (shipId == null || widget.slot != FittingSlot.rigSlot) {
      setState(() => _shipAttrsLoaded = true);
      return;
    }
    final attrs = await ref
        .read(typesDatabaseProvider)
        .typeDogmaAttributes(shipId);
    if (!mounted) return;
    setState(() {
      _rigSizeFilter = (attrs[1547])?.toInt();
      _shipAttrsLoaded = true;
    });
  }

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
          : !_shipAttrsLoaded
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        autofocus: true,
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
                        rigSize: _rigSizeFilter,
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
    required this.rigSize,
  });

  final int effectId;
  final String query;
  final int? rigSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(typesDatabaseRevisionProvider);
    final db = ref.watch(typesDatabaseProvider);
    return FutureBuilder<List<TypeMatch>>(
      future: db.searchTypesByEffect(
        effectId: effectId,
        query: query,
        rigSize: rigSize,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snap.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('No matches'));
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final m = results[i];
            final groupName =
                m.groupId == null ? null : db.lookupGroup(m.groupId!);
            return ListTile(
              leading: EveTypeImage(
                typeId: m.typeId,
                size: 36,
                borderRadius: BorderRadius.circular(4),
              ),
              title: Text(m.name),
              subtitle: groupName == null ? null : Text(groupName),
              onTap: () => Navigator.of(context).pop<int>(m.typeId),
            );
          },
        );
      },
    );
  }
}
