import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/types/types_database_providers.dart';
import '../data/dto/fitting.dart';
import '../data/dto/local_fitting.dart';
import '../domain/eft_format.dart';
import '../local_fitting_providers.dart';
import 'fitting_editor_body.dart';
import 'fitting_editor_controller.dart';

class LocalFittingDetailScreen extends ConsumerStatefulWidget {
  const LocalFittingDetailScreen({
    super.key,
    required this.localId,
    this.characterId,
  });

  final int localId;

  /// When set, the resources panel uses this character's skills. Local
  /// fits aren't bound to a pilot, so this is just a "view as" hint
  /// from whichever screen opened us.
  final int? characterId;

  @override
  ConsumerState<LocalFittingDetailScreen> createState() =>
      _LocalFittingDetailScreenState();
}

class _LocalFittingDetailScreenState
    extends ConsumerState<LocalFittingDetailScreen> {
  LocalFitting? _fit;
  FittingEditorController? _controller;
  String? _error;

  // Serializes saves so a fast burst of edits can't issue overlapping
  // transactions; each new save chains onto the last one.
  Future<void> _saveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(localFittingRepositoryProvider);
      final fit = await repo.get(widget.localId);
      if (fit == null) {
        setState(() => _error = 'Fitting not found');
        return;
      }
      final typesDb = ref.read(typesDatabaseProvider);
      final typeNames = <int, String>{
        fit.shipTypeId: typesDb.lookup(fit.shipTypeId) ?? '#${fit.shipTypeId}',
        for (final i in fit.items)
          i.typeId: typesDb.lookup(i.typeId) ?? '#${i.typeId}',
      };
      final controller = FittingEditorController(
        initialItems: fit.items,
        initialTypeNames: typeNames,
      )..addListener(_onChanged);
      setState(() {
        _fit = fit;
        _controller = controller;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveQueue = _saveQueue.then((_) async {
      final ctrl = _controller;
      if (ctrl == null) return;
      await ref
          .read(localFittingRepositoryProvider)
          .updateItems(widget.localId, ctrl.items);
      if (mounted) {
        ref.read(localFittingsRevisionProvider.notifier).bump();
      }
    });
  }

  Future<void> _renameDialog() async {
    final fit = _fit;
    if (fit == null) return;
    final nameCtrl = TextEditingController(text: fit.name);
    final descCtrl = TextEditingController(text: fit.description);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final newName = nameCtrl.text.trim();
    if (newName.isEmpty) return;
    await ref.read(localFittingRepositoryProvider).rename(
          widget.localId,
          name: newName,
          description: descCtrl.text.trim(),
        );
    ref.read(localFittingsRevisionProvider.notifier).bump();
    if (!mounted) return;
    setState(() {
      _fit = _fit?.copyWith(name: newName, description: descCtrl.text.trim());
    });
  }

  Future<void> _deleteDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this fitting?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _saveQueue;
    await ref.read(localFittingRepositoryProvider).delete(widget.localId);
    ref.read(localFittingsRevisionProvider.notifier).bump();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _copyEft() async {
    final fit = _fit;
    final ctrl = _controller;
    if (fit == null || ctrl == null) return;
    final exportable = Fitting(
      fittingId: 0,
      name: fit.name,
      description: fit.description,
      shipTypeId: fit.shipTypeId,
      items: ctrl.items,
    );
    await Clipboard.setData(
        ClipboardData(text: exportEft(exportable, ctrl.typeNames)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied as EFT')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final fit = _fit;
    final ctrl = _controller;
    if (fit == null || ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(fit.name),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _renameDialog,
          ),
          IconButton(
            tooltip: 'Copy as EFT',
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: _copyEft,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteDialog,
          ),
        ],
      ),
      body: FittingEditorBody(
        shipTypeId: fit.shipTypeId,
        shipName: ctrl.resolveName(fit.shipTypeId),
        description: fit.description,
        controller: ctrl,
        characterId: widget.characterId,
      ),
    );
  }
}
