import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/market/data/market_repository.dart';
import '../../../features/market/market_providers.dart';
import '../types_database.dart';
import '../types_database_providers.dart';
import 'eve_type_image.dart';
import 'html_description.dart';

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
      db.typeTraits(widget.typeId),
    ]);
    return _TypeDetail(
      description: results[0] as String?,
      requiredSkills: results[1] as List<TypeRequiredSkill>,
      attributes: results[2] as Map<int, double>,
      traits: results[3] as List<TypeTrait>,
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
                  child: HtmlDescription(
                    html: detail.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (detail.traits.isNotEmpty) ...[
                _Traits(traits: detail.traits, db: db),
                const SizedBox(height: 16),
              ],
              if (detail.requiredSkills.isNotEmpty) ...[
                _RequiredSkills(skills: detail.requiredSkills, db: db),
                const SizedBox(height: 16),
              ],
              _PriceHistory(typeId: widget.typeId),
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
    required this.traits,
  });

  final String? description;
  final List<TypeRequiredSkill> requiredSkills;
  final Map<int, double> attributes;
  final List<TypeTrait> traits;
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

/// Grouped attribute display, mirroring the in-game Show Info layout:
/// one section per `dgm_attribute_categories` row (Structure, Shield,
/// Capacitor, Targeting, …) with attributes sorted alphabetically
/// inside. Attributes whose category is missing or named "NULL" land
/// in a single fallback "Other" section.
class _Attributes extends StatelessWidget {
  const _Attributes({
    required this.attributes,
    required this.db,
    required this.excludeIds,
  });

  final Map<int, double> attributes;
  final TypesDatabase db;
  final Set<int> excludeIds;

  static const _otherCategoryKey = -1;

  @override
  Widget build(BuildContext context) {
    final byCategory = <int, List<(String, double)>>{};
    attributes.forEach((id, value) {
      if (excludeIds.contains(id)) return;
      final name = db.lookupAttributeName(id);
      if (name == null) return;
      final categoryId = db.attributeCategoryId(id);
      final categoryName = categoryId == null
          ? null
          : db.lookupAttributeCategoryName(categoryId);
      final bucket = (categoryId != null &&
              categoryName != null &&
              categoryName.isNotEmpty &&
              categoryName != 'NULL')
          ? categoryId
          : _otherCategoryKey;
      byCategory.putIfAbsent(bucket, () => []).add((name, value));
    });
    if (byCategory.isEmpty) return const SizedBox.shrink();

    final categoryIds = byCategory.keys.toList()
      ..sort((a, b) {
        // "Other" pinned to the end.
        if (a == _otherCategoryKey) return 1;
        if (b == _otherCategoryKey) return -1;
        final an = db.lookupAttributeCategoryName(a) ?? '';
        final bn = db.lookupAttributeCategoryName(b) ?? '';
        return an.compareTo(bn);
      });

    return Column(
      children: [
        for (final cid in categoryIds) ...[
          _Section(
            title: cid == _otherCategoryKey
                ? 'Other'
                : db.lookupAttributeCategoryName(cid) ?? 'Attributes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in (byCategory[cid]!
                  ..sort((a, b) => a.$1.compareTo(b.$1))))
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (cid != categoryIds.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Blue-text bonuses (role + per-skill). Per-skill bonuses are
/// grouped by their skill so the display matches the in-game
/// "Bonuses" tab. Bonus text can carry HTML (`<a href=showinfo:NNN>`),
/// rendered through the same `HtmlDescription` we use for type
/// descriptions.
class _Traits extends StatelessWidget {
  const _Traits({required this.traits, required this.db});

  final List<TypeTrait> traits;
  final TypesDatabase db;

  @override
  Widget build(BuildContext context) {
    // Group while preserving order — typeTraits() sorts role bonuses
    // first, then per-skill in skill_type_id order.
    final groups = <int?, List<TypeTrait>>{};
    final keyOrder = <int?>[];
    for (final t in traits) {
      if (!groups.containsKey(t.skillTypeId)) {
        keyOrder.add(t.skillTypeId);
      }
      groups.putIfAbsent(t.skillTypeId, () => []).add(t);
    }

    return _Section(
      title: 'Traits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final key in keyOrder) ...[
            if (key != keyOrder.first) const SizedBox(height: 12),
            Text(
              key == null
                  ? 'Role bonuses'
                  : '${db.lookup(key) ?? '#$key'} bonuses (per level)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const SizedBox(height: 4),
            for (final t in groups[key]!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.bonus != null) ...[
                      SizedBox(
                        width: 56,
                        child: Text(
                          _formatBonus(t.bonus!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: HtmlDescription(
                        html: t.bonusText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _formatBonus(double v) {
  // Most bonuses are clean integers ("5%", "10%"); keep one decimal
  // for the rest ("7.5%").
  final s = v == v.truncateToDouble()
      ? NumberFormat('#,##0', 'en_US').format(v)
      : NumberFormat('#,##0.#', 'en_US').format(v);
  return '$s%';
}

String _formatValue(double v) {
  if (v == v.truncateToDouble()) {
    return NumberFormat('#,##0', 'en_US').format(v);
  }
  return NumberFormat('#,##0.##', 'en_US').format(v);
}

String _roman(int level) =>
    const ['', 'I', 'II', 'III', 'IV', 'V'][level.clamp(0, 5)];

/// Last 90 days of daily average price in The Forge (Jita) as a small
/// line chart, plus the latest spot value and the 90-day delta.
/// Hides itself silently for non-traded types (skills, NPCs, BPCs)
/// since ESI returns an empty list for those, and on any network
/// failure — price history is decoration, not load-bearing.
class _PriceHistory extends ConsumerWidget {
  const _PriceHistory({required this.typeId});

  final int typeId;

  static const _windowDays = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketHistoryProvider(MarketHistoryKey(
      typeId: typeId,
      regionId: kDefaultMarketRegionId,
    )));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.length < 2) return const SizedBox.shrink();
        final cutoff =
            DateTime.now().subtract(const Duration(days: _windowDays));
        final recent =
            history.where((e) => !e.date.isBefore(cutoff)).toList(growable: false);
        if (recent.length < 2) return const SizedBox.shrink();

        final first = recent.first;
        final last = recent.last;
        final delta = (last.average - first.average) / first.average;
        final theme = Theme.of(context);
        final positive = delta >= 0;

        // Build chart points; x is days since the first sample so the
        // chart auto-spaces ungappy series and naturally shows weekends.
        final points = [
          for (final e in recent)
            FlSpot(
              e.date.difference(first.date).inDays.toDouble(),
              e.average,
            ),
        ];
        var minY = points.first.y;
        var maxY = points.first.y;
        for (final p in points) {
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }
        // Pad the y-range a touch so the line doesn't kiss the edges.
        final pad = (maxY - minY) * 0.08;
        if (pad == 0) {
          minY -= 1;
          maxY += 1;
        } else {
          minY -= pad;
          maxY += pad;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _Section(
            title: 'Price history',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatIsk(last.average)} ISK',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${positive ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: positive ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => [
                            for (final s in spots)
                              LineTooltipItem(
                                '${_formatIsk(s.y)} ISK\n'
                                '${_formatTooltipDate(first.date.add(Duration(days: s.x.toInt())))}',
                                theme.textTheme.bodySmall ?? const TextStyle(),
                              ),
                          ],
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: false,
                          color: theme.colorScheme.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The Forge · last $_windowDays days',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatIsk(double v) {
  if (v >= 1_000_000_000) {
    return '${(v / 1_000_000_000).toStringAsFixed(2)}B';
  }
  if (v >= 1_000_000) {
    return '${(v / 1_000_000).toStringAsFixed(2)}M';
  }
  if (v >= 1_000) {
    return NumberFormat('#,##0.##', 'en_US').format(v);
  }
  return v.toStringAsFixed(2);
}

String _formatTooltipDate(DateTime d) =>
    DateFormat('MMM d, yyyy', 'en_US').format(d);
