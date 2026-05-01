import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../data/dto/fitting.dart';
import '../domain/eft_format.dart';
import '../domain/parsed_to_payload.dart';
import '../fitting_providers.dart';
import '../local_fitting_providers.dart';
import 'fitting_editor_body.dart';
import 'fitting_editor_controller.dart';
import 'local_fitting_detail_screen.dart';

class FittingDetailScreen extends ConsumerWidget {
  const FittingDetailScreen({
    super.key,
    required this.characterId,
    required this.fittingId,
  });

  final int characterId;
  final int fittingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fittingsProvider(characterId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (data) {
        final fitting =
            data.fittings.where((f) => f.fittingId == fittingId).firstOrNull;
        if (fitting == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Fitting')),
            body: const Center(child: Text('Fitting not found')),
          );
        }
        return _EsiFittingView(
          characterId: characterId,
          fitting: fitting,
          typeNames: data.typeNames,
        );
      },
    );
  }
}

class _EsiFittingView extends ConsumerStatefulWidget {
  const _EsiFittingView({
    required this.characterId,
    required this.fitting,
    required this.typeNames,
  });

  final int characterId;
  final Fitting fitting;
  final Map<int, String> typeNames;

  @override
  ConsumerState<_EsiFittingView> createState() => _EsiFittingViewState();
}

class _EsiFittingViewState extends ConsumerState<_EsiFittingView> {
  late final FittingEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FittingEditorController(
      initialItems: widget.fitting.items,
      initialTypeNames: widget.typeNames,
    );
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _saveCopy() async {
    final defaultName = '${widget.fitting.name} (copy)';
    final result = await showDialog<_SaveChoice>(
      context: context,
      builder: (ctx) => _SaveCopyDialog(initialName: defaultName),
    );
    if (result == null) return;
    final items = _controller.items;

    if (result.target == _SaveTarget.local) {
      final id = await ref.read(localFittingRepositoryProvider).create(
            name: result.name,
            description: widget.fitting.description,
            shipTypeId: widget.fitting.shipTypeId,
            items: items,
          );
      ref.read(localFittingsRevisionProvider.notifier).bump();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as local fitting')),
      );
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => LocalFittingDetailScreen(
            localId: id,
            characterId: widget.characterId,
          ),
        ),
      );
      return;
    }

    final payload = FittingPayload(
      name: result.name,
      description: widget.fitting.description,
      shipTypeId: widget.fitting.shipTypeId,
      items: [
        for (final i in items)
          FittingPayloadItem(
            flag: i.flag,
            quantity: i.quantity,
            typeId: i.typeId,
          ),
      ],
      unresolvedNames: const [],
    );
    try {
      await ref
          .read(fittingRepositoryProvider)
          .create(widget.characterId, payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Push failed: ${describeEsiError(e)}')),
      );
      return;
    }
    ref.invalidate(fittingsProvider(widget.characterId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pushed to ESI')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _copyEft() async {
    final fit = Fitting(
      fittingId: widget.fitting.fittingId,
      name: widget.fitting.name,
      description: widget.fitting.description,
      shipTypeId: widget.fitting.shipTypeId,
      items: _controller.items,
    );
    await Clipboard.setData(
        ClipboardData(text: exportEft(fit, _controller.typeNames)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied as EFT')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _controller.isDirty;
    return Scaffold(
      appBar: AppBar(
        title: Text(dirty ? '${widget.fitting.name} •' : widget.fitting.name),
        actions: [
          if (dirty) ...[
            IconButton(
              tooltip: 'Discard edits',
              icon: const Icon(Icons.undo),
              onPressed: _controller.resetToInitial,
            ),
            IconButton(
              tooltip: 'Save copy',
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveCopy,
            ),
          ],
          IconButton(
            tooltip: 'Copy as EFT',
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: _copyEft,
          ),
        ],
      ),
      body: FittingEditorBody(
        shipTypeId: widget.fitting.shipTypeId,
        shipName: _controller.resolveName(widget.fitting.shipTypeId),
        description: widget.fitting.description,
        controller: _controller,
        characterId: widget.characterId,
      ),
    );
  }
}

enum _SaveTarget { local, esi }

class _SaveChoice {
  const _SaveChoice({required this.name, required this.target});
  final String name;
  final _SaveTarget target;
}

class _SaveCopyDialog extends StatefulWidget {
  const _SaveCopyDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveCopyDialog> createState() => _SaveCopyDialogState();
}

class _SaveCopyDialogState extends State<_SaveCopyDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _pop(_SaveTarget target) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_SaveChoice(name: name, target: target));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save copy'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          Text(
            'Local: stays on this device. ESI: pushes a new fitting to '
            'EVE so it shows up in-game.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _pop(_SaveTarget.local),
          child: const Text('Save local'),
        ),
        FilledButton(
          onPressed: () => _pop(_SaveTarget.esi),
          child: const Text('Push to ESI'),
        ),
      ],
    );
  }
}
