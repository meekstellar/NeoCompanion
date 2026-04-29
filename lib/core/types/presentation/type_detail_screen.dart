import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../types_database.dart';
import '../types_database_providers.dart';
import 'eve_type_image.dart';

/// Detail page for any inventory type — items, ships, skills. Pulls
/// description, dogma attributes and required skills from the local SDE.
class TypeDetailScreen extends ConsumerStatefulWidget {
  const TypeDetailScreen({super.key, required this.typeId});

  final int typeId;

  @override
  ConsumerState<TypeDetailScreen> createState() => _TypeDetailScreenState();
}

class _TypeDetailScreenState extends ConsumerState<TypeDetailScreen> {
  late Future<_TypeDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TypeDetail> _load() async {
    final db = ref.read(typesDatabaseProvider);
    final results = await Future.wait([
      db.typeDescription(widget.typeId),
      db.typeRequiredSkills(widget.typeId),
      db.typeDogmaAttributes(widget.typeId),
    ]);
    return _TypeDetail(
      description: results[0] as String?,
      requiredSkills: results[1] as List<TypeRequiredSkill>,
      attributes: results[2] as Map<int, double>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(typesDatabaseProvider);
    final name = db.lookup(widget.typeId) ?? '#${widget.typeId}';
    final groupId = db.typeGroupId(widget.typeId);
    final categoryId = groupId == null ? null : db.groupCategoryId(groupId);
    final groupName = groupId == null ? null : db.lookupGroup(groupId);
    final categoryName =
        categoryId == null ? null : db.lookupCategory(categoryId);
    final isShip = categoryId == 6;
    final isSkill = categoryId == 16;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<_TypeDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(
                typeId: widget.typeId,
                name: name,
                groupName: groupName,
                categoryName: categoryName,
                isShip: isShip,
              ),
              const SizedBox(height: 16),
              if (isSkill) ...[
                _SkillSummary(attributes: detail.attributes, db: db),
                const SizedBox(height: 16),
              ],
              if (detail.description != null &&
                  detail.description!.trim().isNotEmpty) ...[
                _Section(
                  title: 'Description',
                  child: Text(
                    detail.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (detail.requiredSkills.isNotEmpty) ...[
                _RequiredSkills(skills: detail.requiredSkills, db: db),
                const SizedBox(height: 16),
              ],
              _Attributes(
                attributes: detail.attributes,
                db: db,
                excludeIds: _skillRequirementAttributeIds,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeDetail {
  const _TypeDetail({
    required this.description,
    required this.requiredSkills,
    required this.attributes,
  });

  final String? description;
  final List<TypeRequiredSkill> requiredSkills;
  final Map<int, double> attributes;
}

/// Dogma attribute IDs that encode required-skill prereqs. Already
/// rendered by [_RequiredSkills], so we hide them from the generic
/// attribute list to avoid duplication.
const _skillRequirementAttributeIds = <int>{
  182, 183, 184, 1285, 1289, 1290,
  277, 278, 279, 1286, 1287, 1288,
};

class _Header extends StatelessWidget {
  const _Header({
    required this.typeId,
    required this.name,
    required this.groupName,
    required this.categoryName,
    required this.isShip,
  });

  final int typeId;
  final String name;
  final String? groupName;
  final String? categoryName;
  final bool isShip;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            EveTypeImage(
              typeId: typeId,
              kind: isShip ? EveTypeImageKind.render : EveTypeImageKind.icon,
              size: isShip ? 96 : 64,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (categoryName != null) categoryName,
                      if (groupName != null) groupName,
                    ].whereType<String>().join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SkillSummary extends StatelessWidget {
  const _SkillSummary({required this.attributes, required this.db});

  final Map<int, double> attributes;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    final rank = attributes[275]?.toInt();
    final primaryId = attributes[180]?.toInt();
    final secondaryId = attributes[181]?.toInt();
    final primary = primaryId == null ? null : db.lookupAttributeName(primaryId);
    final secondary =
        secondaryId == null ? null : db.lookupAttributeName(secondaryId);

    final children = <Widget>[];
    if (rank != null) children.add(_SummaryRow(label: 'Rank', value: '$rank'));
    if (primary != null) {
      children.add(_SummaryRow(label: 'Primary', value: primary));
    }
    if (secondary != null) {
      children.add(_SummaryRow(label: 'Secondary', value: secondary));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Skill',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _RequiredSkills extends StatelessWidget {
  const _RequiredSkills({required this.skills, required this.db});

  final List<TypeRequiredSkill> skills;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Required skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in skills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TypeDetailScreen(typeId: s.skillTypeId),
                  ),
                ),
                child: Row(
                  children: [
                    EveTypeImage(
                      typeId: s.skillTypeId,
                      size: 28,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        db.lookup(s.skillTypeId) ?? '#${s.skillTypeId}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      _roman(s.level),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Attributes extends StatelessWidget {
  const _Attributes({
    required this.attributes,
    required this.db,
    required this.excludeIds,
  });

  final Map<int, double> attributes;
  final TypesDatabase db;
  final Set<int> excludeIds;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double)>[];
    attributes.forEach((id, value) {
      if (excludeIds.contains(id)) return;
      final name = db.lookupAttributeName(id);
      if (name == null) return;
      rows.add((name, value));
    });
    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    return _Section(
      title: 'Attributes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    _formatValue(r.$2),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatValue(double v) {
  if (v == v.truncateToDouble()) {
    return NumberFormat('#,##0', 'en_US').format(v);
  }
  return NumberFormat('#,##0.##', 'en_US').format(v);
}

String _roman(int level) =>
    const ['', 'I', 'II', 'III', 'IV', 'V'][level.clamp(0, 5)];
