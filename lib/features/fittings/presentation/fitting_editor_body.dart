import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database_providers.dart';
import '../../clones/clones_providers.dart';
import '../data/dto/fitting.dart';
import '../domain/dogma_modifier.dart';
import '../domain/fit_capacitor.dart';
import '../domain/fit_defense.dart';
import '../domain/fit_resources.dart';
import '../domain/slot_grouping.dart';
import '../fitting_providers.dart';
import 'fitting_editor_controller.dart';
import 'fitting_icon.dart';
import 'module_picker_screen.dart';
import 'type_picker_screen.dart';

/// The scrollable body shared by the ESI and the local fitting screens.
/// Wraps the ship hero card, the live resources panel, and the slot
/// sections (where the user taps a row to swap a module). All mutation
/// flows through the [controller] so the host screen can react —
/// autosave for local fits, dirty marker for ESI fits.
class FittingEditorBody extends ConsumerStatefulWidget {
  const FittingEditorBody({
    super.key,
    required this.shipTypeId,
    required this.shipName,
    required this.description,
    required this.controller,
    this.characterId,
  });

  final int shipTypeId;
  final String shipName;
  final String description;
  final FittingEditorController controller;

  /// When set, the resources panel applies this character's skill
  /// bonuses (CPU Management, Power Grid Management, Weapon Upgrades…).
  /// Null means "show base SDE values" — used for fits not bound to a
  /// specific pilot.
  final int? characterId;

  @override
  ConsumerState<FittingEditorBody> createState() => _FittingEditorBodyState();
}

class _FittingEditorBodyState extends ConsumerState<FittingEditorBody> {
  Future<FitResources>? _future;
  FitResources? _last;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _compute();
  }

  @override
  void didUpdateWidget(covariant FittingEditorBody old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _future = _compute();
    }
    if (old.shipTypeId != widget.shipTypeId ||
        old.characterId != widget.characterId) {
      _future = _compute();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() => _future = _compute());
  }

  Future<FitResources> _compute() async {
    final cid = widget.characterId;
    final db = ref.read(typesDatabaseProvider);
    final skills = cid == null
        ? const <int, int>{}
        : await ref.read(characterSkillLevelsProvider(cid).future);
    final pilotMods = cid == null
        ? const <int, List<Modifier>>{}
        : await ref.read(pilotShipModifiersProvider(cid).future);
    return loadFitResources(
      db: db,
      shipTypeId: widget.shipTypeId,
      items: widget.controller.items,
      skills: skills,
      pilotMods: pilotMods,
    );
  }

  /// Builds the slot section list. For Hi/Med/Low/Rig we render rows
  /// for *every* slot the ship has (using the maxima from [resources]),
  /// not just the occupied ones — empty slots need to be tappable so
  /// the user can fit a freshly-created empty fit. Other buckets
  /// (drones, cargo, …) stay item-only since they don't have a fixed
  /// slot count to lay out.
  List<Widget> _buildSlotSections(
    FittingEditorController ctrl,
    Map<FittingSlot, List<FittingItem>> groups,
    FitResources? resources,
  ) {
    const fixedSlots = [
      FittingSlot.highSlot,
      FittingSlot.medSlot,
      FittingSlot.lowSlot,
      FittingSlot.rigSlot,
    ];

    final sections = <Widget>[];
    for (final slot in fixedSlots) {
      final total = resources?.slots[slot]?.total ?? 0;
      if (total <= 0) continue;
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _SlotSection.fixed(
          slot: slot,
          total: total,
          items: groups[slot] ?? const [],
          resolveName: ctrl.resolveName,
          onReplace: (flag) => _replaceSlot(slot, flag),
          onRemove: (flag) => ctrl.removeModule(flag),
        ),
      ));
    }

    // Drone bay: always render (with an Add button) when the ship has
    // any drone capacity, even if no drones are loaded yet.
    final hasDroneBay = (resources?.droneBayMax ?? 0) > 0;
    if (hasDroneBay || (groups[FittingSlot.drone]?.isNotEmpty ?? false)) {
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _SlotSection.itemsOnly(
          slot: FittingSlot.drone,
          items: groups[FittingSlot.drone] ?? const [],
          resolveName: ctrl.resolveName,
          onAdd: _addDrone,
          onEditStack: (item) => _editStack('DroneBay', item),
        ),
      ));
    }

    // Cargo: every ship has a hold, so always render once we have
    // resources loaded.
    final hasCargo = (resources?.cargoMax ?? 0) > 0;
    if (hasCargo || (groups[FittingSlot.cargo]?.isNotEmpty ?? false)) {
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _SlotSection.itemsOnly(
          slot: FittingSlot.cargo,
          items: groups[FittingSlot.cargo] ?? const [],
          resolveName: ctrl.resolveName,
          onAdd: _addCargo,
          onEditStack: (item) => _editStack('Cargo', item),
        ),
      ));
    }

    for (final entry in groups.entries) {
      if (fixedSlots.contains(entry.key)) continue;
      if (entry.key == FittingSlot.drone) continue;
      if (entry.key == FittingSlot.cargo) continue;
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _SlotSection.itemsOnly(
          slot: entry.key,
          items: entry.value,
          resolveName: ctrl.resolveName,
        ),
      ));
    }

    return sections;
  }

  Future<void> _replaceSlot(FittingSlot slot, String flag) async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ModulePickerScreen(
          slot: slot,
          shipTypeId: widget.shipTypeId,
        ),
      ),
    );
    if (picked == null) return;
    final name = ref.read(typesDatabaseProvider).lookup(picked);
    widget.controller.replaceModule(flag, picked, typeName: name);
  }

  Future<void> _addDrone() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => TypePickerScreen(
          title: 'Pick a drone',
          hintText: 'Search drones',
          search: (db, q) =>
              db.searchTypesByCategory(categoryId: 18, query: q),
        ),
      ),
    );
    if (picked == null) return;
    final name = ref.read(typesDatabaseProvider).lookup(picked);
    widget.controller.addStackable('DroneBay', picked, typeName: name);
  }

  Future<void> _addCargo() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => TypePickerScreen(
          title: 'Add to cargo',
          hintText: 'Search items',
          emptyQueryHint: 'Type to search any published item',
          search: (db, q) => db.searchPublishedTypes(query: q),
        ),
      ),
    );
    if (picked == null) return;
    final name = ref.read(typesDatabaseProvider).lookup(picked);
    widget.controller.addStackable('Cargo', picked, typeName: name);
  }

  Future<void> _editStack(String flag, FittingItem item) async {
    final qtyCtrl =
        TextEditingController(text: item.quantity.toString());
    final result = await showDialog<_StackEdit>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.controller.resolveName(item.typeId)),
        content: TextField(
          controller: qtyCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(const _StackEdit.delete()),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(qtyCtrl.text.trim());
              Navigator.of(ctx).pop(q == null ? null : _StackEdit.set(q));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.delete) {
      widget.controller.removeStack(flag, item.typeId);
    } else if (result.quantity != null) {
      widget.controller
          .setStackQuantity(flag, item.typeId, result.quantity!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final groups = groupBySlot(ctrl.items);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                EveTypeImage(
                  typeId: widget.shipTypeId,
                  kind: EveTypeImageKind.render,
                  size: 96,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHIP',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.2,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.shipName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.characterId != null) ...[
          const SizedBox(height: 16),
          _ImplantsCard(characterId: widget.characterId!),
        ],
        const SizedBox(height: 16),
        _DefenseCard(
          shipTypeId: widget.shipTypeId,
          items: ctrl.items,
        ),
        const SizedBox(height: 16),
        _CapacitorCard(
          shipTypeId: widget.shipTypeId,
          items: ctrl.items,
          characterId: widget.characterId,
        ),
        const SizedBox(height: 16),
        FutureBuilder<FitResources>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasData) _last = snap.data;
            final r = _last;
            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: r == null
                        ? const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _ResourcesContent(resources: r),
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildSlotSections(ctrl, groups, r),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// HP, resistances and EHP for the three defense layers — computed
/// from base ship attributes only. Module hardeners will fold in once
/// the dogma engine routes their effects through the modifier
/// framework.
class _DefenseCard extends ConsumerStatefulWidget {
  const _DefenseCard({required this.shipTypeId, required this.items});

  final int shipTypeId;
  final List<FittingItem> items;

  @override
  ConsumerState<_DefenseCard> createState() => _DefenseCardState();
}

class _DefenseCardState extends ConsumerState<_DefenseCard> {
  Future<FitDefense>? _future;
  FitDefense? _last;

  Future<FitDefense> _compute() => loadFitDefense(
        db: ref.read(typesDatabaseProvider),
        shipTypeId: widget.shipTypeId,
        items: widget.items,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _compute();
  }

  @override
  void didUpdateWidget(covariant _DefenseCard old) {
    super.didUpdateWidget(old);
    if (old.shipTypeId != widget.shipTypeId ||
        !identical(old.items, widget.items)) {
      setState(() => _future = _compute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: FutureBuilder<FitDefense>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasData) _last = snap.data;
            final d = _last;
            if (d == null) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _DefenseContent(theme: theme, defense: d);
          },
        ),
      ),
    );
  }
}

class _DefenseContent extends StatelessWidget {
  const _DefenseContent({required this.theme, required this.defense});

  final ThemeData theme;
  final FitDefense defense;

  @override
  Widget build(BuildContext context) {
    const profile = DamageProfile.omni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DEFENSE',
                style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: theme.colorScheme.primary,
                    ),
              ),
            ),
            Text(
              'omni profile',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LayerRow(
          label: 'Shield',
          iconAsset: 'shield',
          layer: defense.shield,
          profile: profile,
        ),
        const SizedBox(height: 6),
        _LayerRow(
          label: 'Armor',
          iconAsset: 'armor',
          layer: defense.armor,
          profile: profile,
        ),
        const SizedBox(height: 6),
        _LayerRow(
          label: 'Hull',
          iconAsset: 'hull',
          layer: defense.hull,
          profile: profile,
        ),
        const Divider(height: 18),
        Row(
          children: [
            Text('Total EHP', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              _fmtInt(defense.totalEhp(profile)),
              style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.label,
    required this.iconAsset,
    required this.layer,
    required this.profile,
  });

  final String label;
  final String iconAsset;
  final DefenseLayer layer;
  final DamageProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = layer.resonances;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FittingIcon(name: iconAsset, size: 22),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '${_fmtInt(layer.hp)} hp',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              '${_fmtInt(layer.ehp(profile))} EHP',
              style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: DefaultTextStyle(
            style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.hintColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
            child: Row(
              children: [
                _ResistChip(iconAsset: 'resist_em', resonance: r.em),
                _ResistChip(iconAsset: 'resist_thermal', resonance: r.thermal),
                _ResistChip(iconAsset: 'resist_kinetic', resonance: r.kinetic),
                _ResistChip(
                    iconAsset: 'resist_explosive', resonance: r.explosive),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResistChip extends StatelessWidget {
  const _ResistChip({required this.iconAsset, required this.resonance});

  final String iconAsset;
  final double resonance;

  @override
  Widget build(BuildContext context) {
    final pct = ((1 - resonance) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittingIcon(name: iconAsset, size: 14),
          const SizedBox(width: 4),
          Text('$pct%'),
        ],
      ),
    );
  }
}

String _fmtInt(double v) {
  if (v >= 100000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

class _CapacitorCard extends ConsumerStatefulWidget {
  const _CapacitorCard({
    required this.shipTypeId,
    required this.items,
    required this.characterId,
  });

  final int shipTypeId;
  final List<FittingItem> items;
  final int? characterId;

  @override
  ConsumerState<_CapacitorCard> createState() => _CapacitorCardState();
}

class _CapacitorCardState extends ConsumerState<_CapacitorCard> {
  Future<FitCapacitor>? _future;
  FitCapacitor? _last;

  Future<FitCapacitor> _compute() async {
    final db = ref.read(typesDatabaseProvider);
    final cid = widget.characterId;
    final pilotMods = cid == null
        ? const <int, List<Modifier>>{}
        : await ref.read(pilotShipModifiersProvider(cid).future);
    return loadFitCapacitor(
      db: db,
      shipTypeId: widget.shipTypeId,
      items: widget.items,
      pilotMods: pilotMods,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _compute();
  }

  @override
  void didUpdateWidget(covariant _CapacitorCard old) {
    super.didUpdateWidget(old);
    if (old.shipTypeId != widget.shipTypeId ||
        !identical(old.items, widget.items) ||
        old.characterId != widget.characterId) {
      setState(() => _future = _compute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: FutureBuilder<FitCapacitor>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasData) _last = snap.data;
            final c = _last;
            if (c == null) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _CapacitorContent(theme: theme, capacitor: c);
          },
        ),
      ),
    );
  }
}

class _CapacitorContent extends StatelessWidget {
  const _CapacitorContent({required this.theme, required this.capacitor});

  final ThemeData theme;
  final FitCapacitor capacitor;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final stable = capacitor.stable;
    final pct = capacitor.stablePercent;
    final secs = capacitor.secondsToEmpty;
    final summary = stable
        ? (pct == null
            ? 'Stable'
            : 'Stable at ${(pct * 100).toStringAsFixed(0)}%')
        : (secs == null ? 'Unstable' : 'Lasts ${_fmtDuration(secs)}');
    final summaryColor = stable ? scheme.primary : scheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const FittingIcon(name: 'capacitor', size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CAPACITOR',
                style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: scheme.primary,
                    ),
              ),
            ),
            Text(
              summary,
              style: theme.textTheme.titleMedium?.copyWith(color: summaryColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CapRow(
          label: 'Capacity',
          value:
              '${_fmtNum(capacitor.capacity)} GJ',
        ),
        const SizedBox(height: 4),
        _CapRow(
          label: 'Recharge',
          value: '${capacitor.rechargeSeconds.toStringAsFixed(1)} s',
        ),
        const SizedBox(height: 4),
        _CapRow(
          label: 'Peak recharge',
          value: '${capacitor.peakRechargePerSec.toStringAsFixed(2)} GJ/s',
        ),
        const SizedBox(height: 4),
        _CapRow(
          label: 'Module drain',
          value: '${capacitor.drainPerSec.toStringAsFixed(2)} GJ/s',
          highlight: !stable,
        ),
      ],
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: highlight ? theme.colorScheme.error : null,
              ),
        ),
      ],
    );
  }
}

String _fmtNum(double v) {
  if (v >= 10000) return v.toStringAsFixed(0);
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String _fmtDuration(double seconds) {
  if (seconds >= 7200) return '${(seconds / 60).toStringAsFixed(0)} min';
  if (seconds >= 60) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).round();
    return '${m}m ${s}s';
  }
  return '${seconds.toStringAsFixed(0)}s';
}

/// Shows the active character's slotted implants. CPU / power grid /
/// capacitor implant bonuses are applied to the resources and
/// capacitor cards through the dogma framework. Other implant kinds
/// (agility, drone damage, scan res, …) only land once their target
/// attributes are modelled — bonus values still aren't actually
/// reflected for those.
class _ImplantsCard extends ConsumerWidget {
  const _ImplantsCard({required this.characterId});

  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeImplantsProvider(characterId));
    final implants = async.asData?.value;
    if (implants == null || implants.isEmpty) {
      // Hide the card entirely while loading or when the character has
      // no implants — saves vertical space on a clean clone.
      return const SizedBox.shrink();
    }
    final db = ref.watch(typesDatabaseProvider);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMPLANTS',
              style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            ...implants.map((id) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      EveTypeImage(
                        typeId: id,
                        size: 28,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          db.lookup(id) ?? '#$id',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ResourcesContent extends StatelessWidget {
  const _ResourcesContent({required this.resources});

  final FitResources resources;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RESOURCES', style: labelStyle),
        const SizedBox(height: 12),
        _ResourceBar(
          label: 'CPU',
          iconAsset: 'cpu',
          used: resources.cpuUsed,
          max: resources.cpuMax,
          unit: 'tf',
        ),
        const SizedBox(height: 8),
        _ResourceBar(
          label: 'Power',
          iconAsset: 'powergrid',
          used: resources.powerUsed,
          max: resources.powerMax,
          unit: 'MW',
        ),
        if (resources.calibrationMax > 0) ...[
          const SizedBox(height: 8),
          _ResourceBar(
            label: 'Calibration',
            iconAsset: 'rigslot',
            used: resources.calibrationUsed,
            max: resources.calibrationMax,
            unit: '',
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final entry in resources.slots.entries)
              _SlotPill(label: _slotLabel(entry.key), usage: entry.value),
            if (resources.turretHardpoints.total > 0 ||
                resources.turretHardpoints.used > 0)
              _SlotPill(label: 'Turret', usage: resources.turretHardpoints),
            if (resources.launcherHardpoints.total > 0 ||
                resources.launcherHardpoints.used > 0)
              _SlotPill(label: 'Launcher', usage: resources.launcherHardpoints),
          ],
        ),
        if (resources.cargoMax > 0) ...[
          const SizedBox(height: 8),
          _ResourceBar(
            label: 'Cargo',
            iconAsset: 'cargo',
            used: resources.cargoUsed,
            max: resources.cargoMax,
            unit: 'm³',
          ),
        ],
        if (resources.droneBayMax > 0) ...[
          const SizedBox(height: 8),
          _ResourceBar(
            label: 'Drone bay',
            iconAsset: 'drones',
            used: resources.droneBayUsed,
            max: resources.droneBayMax,
            unit: 'm³',
          ),
        ],
        if (resources.droneBandwidthMax > 0) ...[
          const SizedBox(height: 8),
          _ResourceBar(
            label: 'Bandwidth',
            iconAsset: 'drones',
            used: resources.droneBandwidthUsed,
            max: resources.droneBandwidthMax,
            unit: 'Mbit/s',
          ),
        ],
      ],
    );
  }
}

String _slotLabel(FittingSlot slot) => switch (slot) {
      FittingSlot.highSlot => 'Hi',
      FittingSlot.medSlot => 'Med',
      FittingSlot.lowSlot => 'Low',
      FittingSlot.rigSlot => 'Rig',
      FittingSlot.subsystem => 'Sub',
      _ => slot.title,
    };

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({
    required this.label,
    required this.iconAsset,
    required this.used,
    required this.max,
    required this.unit,
  });

  final String label;
  final String iconAsset;
  final double used;
  final double max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);
    final over = max > 0 && used > max;
    final scheme = Theme.of(context).colorScheme;
    final color = over
        ? scheme.error
        : ratio > 0.95
            ? Colors.orange
            : scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FittingIcon(name: iconAsset, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Text(
              '${_fmt(used)} / ${_fmt(max)}${unit.isEmpty ? '' : ' $unit'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: over ? scheme.error : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: max <= 0 ? 0 : ratio,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label, required this.usage});

  final String label;
  final SlotUsage usage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = usage.used > usage.total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: over ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label ${usage.used}/${usage.total}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: over ? scheme.onErrorContainer : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}

/// Result of the drone/cargo stack-edit dialog.
class _StackEdit {
  const _StackEdit.set(this.quantity) : delete = false;
  const _StackEdit.delete()
      : delete = true,
        quantity = null;
  final bool delete;
  final int? quantity;
}

/// In-game flag prefix for slots with a fixed numeric layout.
String _slotFlagPrefix(FittingSlot slot) => switch (slot) {
      FittingSlot.highSlot => 'HiSlot',
      FittingSlot.medSlot => 'MedSlot',
      FittingSlot.lowSlot => 'LoSlot',
      FittingSlot.rigSlot => 'RigSlot',
      FittingSlot.subsystem => 'SubSystemSlot',
      _ => '',
    };

class _SlotSection extends StatelessWidget {
  /// Renders [total] rows for a slot kind that has a fixed in-game
  /// layout (Hi/Med/Low/Rig). Empty slots get a tappable placeholder
  /// so the user can fit a fresh, blank fit.
  const _SlotSection.fixed({
    required this.slot,
    required this.total,
    required this.items,
    required this.resolveName,
    required this.onReplace,
    required this.onRemove,
  })  : onAdd = null,
        onEditStack = null,
        _itemsOnly = false;

  /// Renders the section as the simple item list — used for buckets
  /// that don't have a fixed slot count to draw placeholders for
  /// (drones, cargo, …). Pass [onAdd] to surface a "+" affordance and
  /// [onEditStack] to make rows tappable for quantity edit / remove.
  const _SlotSection.itemsOnly({
    required this.slot,
    required this.items,
    required this.resolveName,
    this.onAdd,
    this.onEditStack,
  })  : total = 0,
        onReplace = null,
        onRemove = null,
        _itemsOnly = true;

  final FittingSlot slot;
  final int total;
  final List<FittingItem> items;
  final String Function(int) resolveName;
  final void Function(String flag)? onReplace;
  final void Function(String flag)? onRemove;
  final VoidCallback? onAdd;
  final void Function(FittingItem item)? onEditStack;
  final bool _itemsOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                  ),
                ),
                if (_itemsOnly && onAdd != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_itemsOnly) ..._itemsOnlyRows(theme) else ..._fixedRows(theme),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _itemsOnlyRows(ThemeData theme) sync* {
    if (items.isEmpty && onAdd != null) {
      yield Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Empty — tap + to add',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      );
      return;
    }
    for (final it in items) {
      final row = _occupiedRow(theme, it);
      final cb = onEditStack;
      yield cb == null ? row : InkWell(onTap: () => cb(it), child: row);
    }
  }

  Iterable<Widget> _fixedRows(ThemeData theme) sync* {
    final byFlag = {for (final it in items) it.flag: it};
    final prefix = _slotFlagPrefix(slot);
    for (var i = 0; i < total; i++) {
      final flag = '$prefix$i';
      final item = byFlag[flag];
      yield InkWell(
        onTap: () => onReplace?.call(flag),
        onLongPress: item == null ? null : () => onRemove?.call(flag),
        child: item == null
            ? _emptyRow(theme)
            : _occupiedRow(theme, item),
      );
    }
  }

  Widget _emptyRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(Icons.add, size: 18, color: theme.hintColor),
          ),
          const SizedBox(width: 12),
          Text(
            'Empty',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _occupiedRow(ThemeData theme, FittingItem it) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          EveTypeImage(
            typeId: it.typeId,
            size: 32,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              resolveName(it.typeId),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (it.quantity > 1)
            Text(
              '×${it.quantity}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
        ],
      ),
    );
  }
}
