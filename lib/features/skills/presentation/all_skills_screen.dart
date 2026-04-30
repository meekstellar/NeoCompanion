import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/esi_error_message.dart';
import '../../../core/types/presentation/eve_type_image.dart';
import '../../../core/types/presentation/type_detail_screen.dart';
import '../data/dto/character_skills.dart';
import '../skill_providers.dart';

class AllSkillsScreen extends ConsumerStatefulWidget {
  const AllSkillsScreen({super.key, required this.characterId});

  final int characterId;

  @override
  ConsumerState<AllSkillsScreen> createState() => _AllSkillsScreenState();
}

class _AllSkillsScreenState extends ConsumerState<AllSkillsScreen> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allSkillsProvider(widget.characterId));
    return Scaffold(
      appBar: AppBar(title: const Text('All skills')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeEsiError(e))),
        data: _build,
      ),
    );
  }

  Widget _build(AllSkillsData data) {
    final query = _filter.text.trim().toLowerCase();
    final entries = data.skills.skills
        .map((s) {
          final name = data.names[s.skillId] ?? '#${s.skillId}';
          return _Entry(skill: s, name: name);
        })
        .where((e) => query.isEmpty || e.name.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Filter by name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                '${entries.length} of ${data.skills.skills.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${_formatInt(data.skills.totalSp)} SP',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No matching skills'))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, i) => _SkillRow(entry: entries[i]),
                ),
        ),
      ],
    );
  }
}

class _Entry {
  _Entry({required this.skill, required this.name});
  final SkillSummary skill;
  final String name;
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.entry});
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final s = entry.skill;
    return ListTile(
      dense: true,
      leading: EveTypeImage(
        typeId: s.skillId,
        size: 32,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(entry.name),
      subtitle: Text('${_formatInt(s.skillpointsInSkill)} SP'),
      trailing: _LevelDots(level: s.activeSkillLevel),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TypeDetailScreen(typeId: s.skillId),
        ),
      ),
    );
  }
}

class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final filled = Theme.of(context).colorScheme.primary;
    final empty = Theme.of(context).hintColor.withValues(alpha: 0.3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: i < level ? filled : empty,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

String _formatInt(int n) => NumberFormat('#,##0', 'en_US').format(n);
