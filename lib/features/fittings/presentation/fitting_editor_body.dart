import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/types_database_providers.dart';
import '../../clones/clones_providers.dart';
import '../data/dto/fitting.dart';
import '../domain/dogma_modifier.dart';
import '../domain/fit_capacitor.dart';
import '../domain/fit_compatibility.dart';
import '../domain/fit_defense.dart';
import '../domain/fit_misc.dart';
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

/// Bundle of all three live computes. Hoisting them into one state
/// blob means a single recompute pass per edit, and the compact
/// summary bar at the top of the editor can render every key number
/// from one source of truth.
class _FitData {
  const _FitData({
    required this.resources,
    required this.defense,
    required this.capacitor,
    required this.misc,
  });

  final FitResources resources;
  final FitDefense defense;
  final FitCapacitor capacitor;
  final FitMisc misc;
}

class _FittingEditorBodyState extends ConsumerState<FittingEditorBody> {
  Future<_FitData>? _future;
  _FitData? _last;

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

  Future<_FitData> _compute() async {
    final cid = widget.characterId;
    final db = ref.read(typesDatabaseProvider);
    final skills = cid == null
        ? const <int, int>{}
        : await ref.read(characterSkillLevelsProvider(cid).future);
    final pilotMods = cid == null
        ? const <int, List<Modifier>>{}
        : await ref.read(pilotShipModifiersProvider(cid).future);
    final items = widget.controller.items;

    final results = await Future.wait<Object>([
      loadFitResources(
        db: db,
        shipTypeId: widget.shipTypeId,
        items: items,
        skills: skills,
        pilotMods: pilotMods,
      ),
      loadFitDefense(
        db: db,
        shipTypeId: widget.shipTypeId,
        items: items,
      ),
      loadFitCapacitor(
        db: db,
        shipTypeId: widget.shipTypeId,
        items: items,
        pilotMods: pilotMods,
      ),
      loadFitMisc(
        db: db,
        shipTypeId: widget.shipTypeId,
        pilotMods: pilotMods,
      ),
    ]);

    return _FitData(
      resources: results[0] as FitResources,
      defense: results[1] as FitDefense,
      capacitor: results[2] as FitCapacitor,
      misc: results[3] as FitMisc,
    );
  }

  Future<void> _replaceSlot(FittingSlot slot, String flag) async {
    final fitted = widget.controller.items
        .where((it) => it.flag == flag)
        .firstOrNull;
    final result = await Navigator.of(context).push<ModulePickerResult>(
      MaterialPageRoute(
        builder: (_) => ModulePickerScreen(
          slot: slot,
          fittedTypeId: fitted?.typeId,
        ),
      ),
    );
    if (result == null) return;
    if (result is ModuleRemoved) {
      widget.controller.removeModule(flag);
      return;
    }
    final picked = (result as ModulePicked).typeId;
    final db = ref.read(typesDatabaseProvider);
    final conflicts = await validateModuleFit(
      db: db,
      moduleTypeId: picked,
      shipTypeId: widget.shipTypeId,
      slot: slot,
      currentItems: widget.controller.items,
    );
    if (conflicts.isNotEmpty) {
      if (!mounted) return;
      final proceed = await _showConflictDialog(picked, conflicts);
      if (proceed != true) return;
    }
    final name = db.lookup(picked);
    widget.controller.replaceModule(flag, picked, typeName: name);
  }

  Future<bool?> _showConflictDialog(
    int moduleTypeId,
    List<FitConflict> conflicts,
  ) {
    final name = ref
            .read(typesDatabaseProvider)
            .lookup(moduleTypeId) ??
        'Module';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not compatible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            for (final c in conflicts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${c.message}'),
              ),
            const SizedBox(height: 12),
            Text(
              'Fit anyway?',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).hintColor,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Fit anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDrone() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => TypePickerScreen(
          title: 'Pick a drone',
          hintText: 'Search drones',
          search: (db, q) =>
              db.searchTypesByCategory(categoryId: 18, query: q),
          // Market group 157 = "Drones".
          rootMarketGroupId: 157,
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
          search: (db, q) => db.searchPublishedTypes(query: q),
          // Empty query opens the in-game market browser instead of a
          // bare hint — cargo can hold anything, so let the player
          // drill the tree when they don't know the exact name.
          browseWhenEmpty: true,
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

    return FutureBuilder<_FitData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) _last = snap.data;
        final data = _last;

        return CustomScrollView(
          slivers: [
            // Hero card with key stats fused in — saves the height
            // of the old separate summary bar, and the panels below
            // (Resources + Defense expanded) carry the rest.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: _CompactHero(
                  shipTypeId: widget.shipTypeId,
                  shipName: widget.shipName,
                  description: widget.description,
                  data: data,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _SlotsCard(
                  shipTypeId: widget.shipTypeId,
                  items: ctrl.items,
                  groups: groups,
                  resources: data?.resources,
                  onReplaceSlot: _replaceSlot,
                  onRemoveSlot: ctrl.removeModule,
                ),
                if ((data?.resources.droneBayMax ?? 0) > 0 ||
                    (groups[FittingSlot.drone]?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StackStripCard(
                      title: 'DRONES',
                      iconAsset: 'drones',
                      items: groups[FittingSlot.drone] ?? const [],
                      resolveName: ctrl.resolveName,
                      onAdd: _addDrone,
                      onEditStack: (item) => _editStack('DroneBay', item),
                    ),
                  ),
                if ((data?.resources.cargoMax ?? 0) > 0 ||
                    (groups[FittingSlot.cargo]?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StackStripCard(
                      title: 'CARGO',
                      iconAsset: 'cargo',
                      items: groups[FittingSlot.cargo] ?? const [],
                      resolveName: ctrl.resolveName,
                      onAdd: _addCargo,
                      onEditStack: (item) => _editStack('Cargo', item),
                    ),
                  ),
                if (widget.characterId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _ImplantsCard(characterId: widget.characterId!),
                  ),
                // Stat panels — plain cards without titles. The hero
                // already gives the at-a-glance numbers; these are the
                // detailed breakdowns for players who want them.
                if (data != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StatCard(
                      child: _ResourcesContent(resources: data.resources),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StatCard(
                      child: _DefenseContent(
                        theme: Theme.of(context),
                        defense: data.defense,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StatCard(
                      child: _CapacitorContent(
                        theme: Theme.of(context),
                        capacitor: data.capacitor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StatCard(
                      child: _TargetingContent(misc: data.misc),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StatCard(
                      child: _NavigationContent(misc: data.misc),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ]),
            ),
          ],
        );
      },
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
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(48),
        2: FixedColumnWidth(48),
        3: FixedColumnWidth(48),
        4: FixedColumnWidth(48),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row holds total EHP on the left and the four damage
        // type icons across the right — keeps the card compact by
        // sharing a row instead of stacking another above the table.
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_fmtInt(defense.totalEhp(profile))} EHP',
                style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const _ResistHeader(iconAsset: 'resist_em'),
            const _ResistHeader(iconAsset: 'resist_thermal'),
            const _ResistHeader(iconAsset: 'resist_kinetic'),
            const _ResistHeader(iconAsset: 'resist_explosive'),
          ],
        ),
        _layerRow('shield', defense.shield, profile),
        _layerRow('armor', defense.armor, profile),
        _layerRow('hull', defense.hull, profile),
      ],
    );
  }

  TableRow _layerRow(
    String iconAsset,
    DefenseLayer layer,
    DamageProfile profile,
  ) {
    final r = layer.resonances;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              FittingIcon(name: iconAsset, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_fmtInt(layer.hp)} hp',
                style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
        _ResistCell(resonance: r.em, tint: const Color(0xFF6FB5FF)),
        _ResistCell(resonance: r.thermal, tint: const Color(0xFFFF6B6B)),
        _ResistCell(resonance: r.kinetic, tint: const Color(0xFFCFD8DC)),
        _ResistCell(resonance: r.explosive, tint: const Color(0xFFFFC95C)),
      ],
    );
  }
}

class _ResistHeader extends StatelessWidget {
  const _ResistHeader({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(child: FittingIcon(name: iconAsset, size: 18)),
    );
  }
}

class _ResistCell extends StatelessWidget {
  const _ResistCell({required this.resonance, required this.tint});

  final double resonance;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = ((1 - resonance) * 100).round();
    final ratio = (pct / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(3),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Damage-type tinted fill, width proportional to resist
            // percent — gives an at-a-glance read of "how covered is
            // this damage type" without the user parsing numbers.
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(color: tint.withValues(alpha: 0.55)),
            ),
            Center(
              child: Text(
                '$pct%',
                style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtInt(double v) {
  if (v >= 100000) return '${(v / 1000).toStringAsFixed(0)}k';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
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
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(color: summaryColor),
          ),
        ),
        const SizedBox(height: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

/// Compact ship hero — a small render plus the ship name. The
/// description (when set) lives in a `Tooltip` so it doesn't eat
/// vertical space on the main view.
/// Hero card for the ship — render + name + description on one line,
/// plus a compact stat row at the bottom (CPU%, PG%, EHP, cap
/// stability) so the user always sees the at-a-glance numbers without
/// a separate pinned bar.
class _CompactHero extends StatelessWidget {
  const _CompactHero({
    required this.shipTypeId,
    required this.shipName,
    required this.description,
    required this.data,
  });

  final int shipTypeId;
  final String shipName;
  final String description;
  final _FitData? data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = description.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EveTypeImage(
              typeId: shipTypeId,
              kind: EveTypeImageKind.render,
              size: 64,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shipName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  if (data != null) _HeroStatsRow(data: data!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatsRow extends StatelessWidget {
  const _HeroStatsRow({required this.data});

  final _FitData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = data.resources;
    final ehp = data.defense.totalEhp(DamageProfile.omni);
    final cap = data.capacitor;
    final capLabel = cap.stable
        ? (cap.stablePercent == null
            ? 'Stable'
            : '${(cap.stablePercent! * 100).toStringAsFixed(0)}%')
        : (cap.secondsToEmpty == null
            ? 'Out'
            : _fmtDuration(cap.secondsToEmpty!));

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SummaryStat(
          iconAsset: 'cpu',
          value: _pctOrDash(r.cpuUsed, r.cpuMax),
          over: r.cpuUsed > r.cpuMax,
        ),
        _SummaryStat(
          iconAsset: 'powergrid',
          value: _pctOrDash(r.powerUsed, r.powerMax),
          over: r.powerUsed > r.powerMax,
        ),
        _SummaryStat(
          iconAsset: 'shield',
          value: '${_fmtInt(ehp)} EHP',
        ),
        _SummaryStat(
          iconAsset: 'capacitor',
          value: capLabel,
          color: cap.stable
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ],
    );
  }

  String _pctOrDash(double used, double max) {
    if (max <= 0) return '—';
    final pct = (used / max * 100).clamp(0, 999).round();
    return '$pct%';
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.iconAsset,
    required this.value,
    this.over = false,
    this.color,
  });

  final String iconAsset;
  final String value;
  final bool over;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = over ? theme.colorScheme.error : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittingIcon(name: iconAsset, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: effective,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

/// One card holding the four fixed slot strips (Hi/Med/Low/Rig). Each
/// strip is a compact horizontal row of 40-pt squares — same shape as
/// the in-game fitting window. Tapping a square opens the picker;
/// long-press removes a fitted module.
class _SlotsCard extends StatelessWidget {
  const _SlotsCard({
    required this.shipTypeId,
    required this.items,
    required this.groups,
    required this.resources,
    required this.onReplaceSlot,
    required this.onRemoveSlot,
  });

  final int shipTypeId;
  final List<FittingItem> items;
  final Map<FittingSlot, List<FittingItem>> groups;
  final FitResources? resources;
  final Future<void> Function(FittingSlot slot, String flag) onReplaceSlot;
  final void Function(String flag) onRemoveSlot;

  static const _fixedSlots = [
    FittingSlot.highSlot,
    FittingSlot.medSlot,
    FittingSlot.lowSlot,
    FittingSlot.rigSlot,
  ];

  @override
  Widget build(BuildContext context) {
    final r = resources;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              for (final slot in _fixedSlots)
                if ((r?.slots[slot]?.total ?? 0) > 0 ||
                    (groups[slot]?.isNotEmpty ?? false))
                  _SlotStrip(
                    slot: slot,
                    total: r?.slots[slot]?.total ?? 0,
                    items: groups[slot] ?? const [],
                    rightSide: _slotStripRight(slot, r),
                    onTap: (flag) => onReplaceSlot(slot, flag),
                    onLongPress: onRemoveSlot,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _slotStripRight(FittingSlot slot, FitResources? r) {
    if (r == null) return null;
    switch (slot) {
      case FittingSlot.highSlot:
        final th = r.turretHardpoints;
        final lh = r.launcherHardpoints;
        return Wrap(
          spacing: 8,
          children: [
            if (th.total > 0 || th.used > 0)
              _MiniBadge(
                iconAsset: 'turret',
                text: '${th.used}/${th.total}',
                over: th.used > th.total,
              ),
            if (lh.total > 0 || lh.used > 0)
              _MiniBadge(
                iconAsset: 'launcher',
                text: '${lh.used}/${lh.total}',
                over: lh.used > lh.total,
              ),
          ],
        );
      case FittingSlot.rigSlot:
        if (r.calibrationMax <= 0) return null;
        return _MiniBadge(
          iconAsset: 'rigslot',
          text: '${r.calibrationUsed.toStringAsFixed(0)}/'
              '${r.calibrationMax.toStringAsFixed(0)}',
          over: r.calibrationUsed > r.calibrationMax,
        );
      default:
        return null;
    }
  }
}

class _SlotStrip extends StatelessWidget {
  const _SlotStrip({
    required this.slot,
    required this.total,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    this.rightSide,
  });

  final FittingSlot slot;
  final int total;
  final List<FittingItem> items;
  final void Function(String flag) onTap;
  final void Function(String flag) onLongPress;
  final Widget? rightSide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byFlag = {for (final it in items) it.flag: it};
    final prefix = _slotFlagPrefix(slot);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _slotShortLabel(slot),
              style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.6,
                    color: theme.hintColor,
                  ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < total; i++)
                  _SlotSquare(
                    item: byFlag['$prefix$i'],
                    onTap: () => onTap('$prefix$i'),
                    onLongPress: () => onLongPress('$prefix$i'),
                  ),
              ],
            ),
          ),
          if (rightSide != null) ...[
            const SizedBox(width: 8),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall ?? const TextStyle(),
              child: rightSide!,
            ),
          ],
        ],
      ),
    );
  }
}

String _slotShortLabel(FittingSlot slot) => switch (slot) {
      FittingSlot.highSlot => 'High',
      FittingSlot.medSlot => 'Mid',
      FittingSlot.lowSlot => 'Low',
      FittingSlot.rigSlot => 'Rig',
      FittingSlot.subsystem => 'Sub',
      _ => '',
    };

class _SlotSquare extends StatelessWidget {
  const _SlotSquare({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final FittingItem? item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final theme = Theme.of(context);
    final fitted = item != null;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      onLongPress: fitted ? onLongPress : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: fitted
                ? theme.colorScheme.outlineVariant
                : theme.dividerColor,
          ),
          color: fitted ? theme.colorScheme.surfaceContainerHighest : null,
        ),
        alignment: Alignment.center,
        child: fitted
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: EveTypeImage(typeId: item!.typeId, size: size - 6),
              )
            : Icon(Icons.add, size: 18, color: theme.hintColor),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.iconAsset,
    required this.text,
    this.over = false,
  });

  final String iconAsset;
  final String text;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittingIcon(name: iconAsset, size: 14),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
                color: over ? theme.colorScheme.error : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

/// Compact horizontal strip for stack-shaped buckets (drone bay,
/// cargo). Each stack is rendered as a slot square with a quantity
/// badge in the top-right corner; tap edits the stack, long-press
/// removes it. The trailing `+` square opens the type picker.
class _StackStripCard extends StatelessWidget {
  const _StackStripCard({
    required this.title,
    required this.iconAsset,
    required this.items,
    required this.resolveName,
    required this.onAdd,
    required this.onEditStack,
  });

  final String title;
  final String iconAsset;
  final List<FittingItem> items;
  final String Function(int) resolveName;
  final VoidCallback onAdd;
  final void Function(FittingItem item) onEditStack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FittingIcon(name: iconAsset, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final it in items)
                  _StackSquare(
                    item: it,
                    onTap: () => onEditStack(it),
                  ),
                _SlotSquare(
                  item: null,
                  onTap: onAdd,
                  onLongPress: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StackSquare extends StatelessWidget {
  const _StackSquare({required this.item, required this.onTap});

  final FittingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: EveTypeImage(typeId: item.typeId, size: size - 6),
              ),
            ),
            if (item.quantity > 1)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Targeting / sensor stats — same compact key/value layout as the
/// Capacitor card.
class _TargetingContent extends StatelessWidget {
  const _TargetingContent({required this.misc});

  final FitMisc misc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiscRow(
          iconAsset: 'targeting_range',
          label: 'Targeting range',
          value: '${_fmtKm(misc.targetingRangeKm)} km',
        ),
        _MiscRow(
          iconAsset: 'max_targets',
          label: 'Locked targets',
          value: '${misc.maxLockedTargets}',
        ),
        _MiscRow(
          iconAsset: 'scan_res',
          label: 'Scan resolution',
          value: '${_fmtNum(misc.scanResolutionMm)} mm',
        ),
        _MiscRow(
          iconAsset: 'signature_radius',
          label: 'Signature radius',
          value: '${_fmtNum(misc.signatureRadius)} m',
        ),
        if (misc.sensorStrength > 0)
          _MiscRow(
            label: 'Sensor strength',
            value: _fmtNum(misc.sensorStrength),
          ),
      ],
    );
  }
}

/// Navigation stats — velocity, warp speed, align time.
class _NavigationContent extends StatelessWidget {
  const _NavigationContent({required this.misc});

  final FitMisc misc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiscRow(
          iconAsset: 'velocity',
          label: 'Max velocity',
          value: '${_fmtNum(misc.maxVelocity)} m/s',
        ),
        _MiscRow(
          iconAsset: 'warp_speed',
          label: 'Warp speed',
          value: '${misc.warpSpeed.toStringAsFixed(2)} AU/s',
        ),
        _MiscRow(
          iconAsset: 'align_time',
          label: 'Align time',
          value: '${misc.alignTimeSeconds.toStringAsFixed(2)} s',
        ),
      ],
    );
  }
}

class _MiscRow extends StatelessWidget {
  const _MiscRow({
    required this.label,
    required this.value,
    this.iconAsset,
  });

  final String label;
  final String value;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (iconAsset != null) ...[
            FittingIcon(name: iconAsset!, size: 16),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}

String _fmtKm(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  if (v >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

/// Plain card wrapper around a stat panel — no title, no expansion.
/// Players know shield/armor/hull and CPU/PG by sight; spelling out
/// "Resources" / "Defense" above the content is just chrome. Padding
/// mirrors the slots card so the columns line up across blocks.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      ),
    );
  }
}
