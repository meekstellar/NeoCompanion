import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/esi_error_message.dart';
import '../../characters/character_providers.dart';
import '../domain/eft_parser.dart';
import '../domain/parsed_to_payload.dart';
import '../fitting_providers.dart';

class EftImportScreen extends ConsumerStatefulWidget {
  const EftImportScreen({super.key, required this.characterId});

  final int characterId;

  @override
  ConsumerState<EftImportScreen> createState() => _EftImportScreenState();
}

class _EftImportScreenState extends ConsumerState<EftImportScreen> {
  final _controller = TextEditingController();
  ParsedFitting? _parsed;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _error = null;
      _parsed = null;
    });
    try {
      final parsed = parseEft(_controller.text);
      setState(() => _parsed = parsed);
    } on EftParseException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final parsed = _parsed;
    if (parsed == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final names = <String>{
        parsed.shipName,
        for (final i in parsed.items) i.name,
      }.toList();
      final character = ref.read(characterRepositoryProvider);
      final nameToId = await character.resolveIds(names);

      final payload = toPayload(parsed, nameToId);

      if (payload.unresolvedNames.isNotEmpty) {
        setState(() {
          _error = 'Unknown items: ${payload.unresolvedNames.join(', ')}';
          _submitting = false;
        });
        return;
      }

      final repo = ref.read(fittingRepositoryProvider);
      await repo.create(widget.characterId, payload);

      ref.invalidate(fittingsProvider(widget.characterId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = describeEsiError(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from EFT')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '[Rifter, My Fit]\n\nDamage Control II\n...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (parsed != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ship: ${parsed.shipName} • '
                'Name: ${parsed.fitName} • '
                '${parsed.items.length} items',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _submitting ? null : _parse,
                  child: const Text('Parse'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (parsed != null && !_submitting) ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
