import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqflite.dart';

import 'sde_schema.dart';
export 'sde_schema.dart'
    show
        kSdeSchemaVersion,
        sdeLanguages,
        sdeDefaultLanguage,
        TypeMatch,
        TypeRequiredSkill,
        TypeTrait,
        createSdeSchema,
        createSdeIndexes,
        openExistingSdeDatabase;

/// Persistent local copy of CCP's Static Data Export, normalized into
/// SQLite. Backed by a real DB file in production; tests pass `null` to
/// run with in-memory caches only.
///
/// Hot caches mirror the most-used English name maps so widget builders
/// can resolve names synchronously. Everything else (descriptions,
/// dogma attributes, required skills, non-English names) is queried
/// from SQLite on demand.
class TypesDatabase extends ChangeNotifier {
  TypesDatabase(this._db, {this.path});

  /// Filesystem path of the SQLite file backing this database (null in
  /// tests / when no DB is open). Used by the updater to atomically swap
  /// in a freshly-imported file.
  final String? path;

  /// Schema version of *our* SQLite layout (independent of CCP's SDE
  /// build number). Bumping invalidates cached data and forces a
  /// re-import through the gate. Mirrors the canonical [kSdeSchemaVersion]
  /// constant in `sde_schema.dart` (kept on the class for ergonomic
  /// `TypesDatabase.schemaVersion` access at call sites).
  static const int schemaVersion = kSdeSchemaVersion;

  Database? _db;

  Map<int, String> _typeNames = const {};
  Map<int, String> _groupNames = const {};
  Map<int, String> _categoryNames = const {};
  Map<int, String> _marketGroupNames = const {};
  Map<int, String> _systemNames = const {};
  Map<int, String> _stationNames = const {};
  Map<int, String> _constellationNames = const {};
  Map<int, String> _regionNames = const {};
  Map<int, String> _factionNames = const {};
  Map<int, String> _raceNames = const {};
  Map<int, String> _bloodlineNames = const {};
  Map<int, String> _npcCorporationNames = const {};
  Map<int, String> _attributeDisplayNames = const {};
  Map<int, String> _attributeCategoryNames = const {};
  Map<int, int?> _attributeCategoryByAttribute = const {};
  Map<String, int> _attributeIdByName = const {};
  Map<int, bool> _attributeStackable = const {};

  Map<int, int?> _groupCategory = const {};
  Map<int, int?> _typeGroup = const {};
  Map<int, List<int>> _typesByGroup = const {};
  Map<int, List<int>> _groupsByCategory = const {};
  Map<int, int?> _marketGroupParent = const {};
  Map<int?, List<int>> _marketGroupChildren = const {};
  Map<int, List<int>> _typesByMarketGroup = const {};
  Map<int, int> _marketGroupSubtreeCount = const {};
  List<int> _typesWithoutMarketGroup = const [];

  int? _buildNumber;
  DateTime? _releaseDate;
  DateTime? _installedAt;

  bool get isReady => _typeNames.isNotEmpty;
  int get count => _typeNames.length;
  int? get buildNumber => _buildNumber;
  DateTime? get releaseDate => _releaseDate;
  DateTime? get installedAt => _installedAt;
  Database? get rawDatabase => _db;

  // Sync hot lookups (English).
  String? lookup(int typeId) => _typeNames[typeId];
  String? lookupGroup(int id) => _groupNames[id];
  int? typeGroupId(int id) => _typeGroup[id];
  int? groupCategoryId(int id) => _groupCategory[id];
  String? lookupCategory(int id) => _categoryNames[id];
  String? lookupMarketGroup(int id) => _marketGroupNames[id];
  String? lookupSystem(int id) => _systemNames[id];

  /// Pre-composed display name for an NPC station id (e.g. "Jita IV -
  /// Moon 4 - Caldari Navy Assembly Plant"). Returns null for player
  /// citadels — those are resolved at runtime via ESI.
  String? lookupStation(int id) => _stationNames[id];
  String? lookupConstellation(int id) => _constellationNames[id];
  String? lookupRegion(int id) => _regionNames[id];
  String? lookupFaction(int id) => _factionNames[id];
  String? lookupRace(int id) => _raceNames[id];
  String? lookupBloodline(int id) => _bloodlineNames[id];
  String? lookupNpcCorporation(int id) => _npcCorporationNames[id];
  String? lookupAttributeName(int attributeId) =>
      _attributeDisplayNames[attributeId];

  /// Display name of the dogma-attribute category (e.g. "Structure",
  /// "Capacitor"). English-only — CCP doesn't translate these.
  String? lookupAttributeCategoryName(int categoryId) =>
      _attributeCategoryNames[categoryId];

  /// Which category an attribute belongs to. Returns null both for
  /// unknown attributes and for attributes the SDE leaves uncategorised.
  int? attributeCategoryId(int attributeId) =>
      _attributeCategoryByAttribute[attributeId];

  /// Resolves a canonical (English, language-independent) attribute
  /// name like `armorEmDamageResonanceMultiplier` to its SDE id. Used
  /// by the dogma engine to find modifier-source and modifier-target
  /// attributes without hardcoding numeric ids.
  int? attributeIdByName(String name) => _attributeIdByName[name];

  /// Whether the attribute is stackable (no penalty applies). Maps to
  /// the SDE's `stackable` flag on the attribute. Defaults to false
  /// for unknown attributes — the safe assumption.
  bool attributeIsStackable(int attributeId) =>
      _attributeStackable[attributeId] ?? false;

  /// Type IDs that belong to [groupId], in no particular order. Empty
  /// when the group has no types in the local cache.
  List<int> typesInGroup(int groupId) => _typesByGroup[groupId] ?? const [];

  /// Group IDs that belong to [categoryId], in no particular order.
  List<int> groupsInCategory(int categoryId) =>
      _groupsByCategory[categoryId] ?? const [];

  /// Direct child market-group IDs of [parentId]. Pass `null` for the
  /// roots (market groups with no parent). Drives the in-game market
  /// browser style hierarchy on the item database screen.
  List<int> marketGroupChildren(int? parentId) =>
      _marketGroupChildren[parentId] ?? const [];

  /// Type IDs whose `market_group_id` is exactly [marketGroupId] (i.e.
  /// directly attached to this group, not to its descendants).
  List<int> typesInMarketGroup(int marketGroupId) =>
      _typesByMarketGroup[marketGroupId] ?? const [];

  /// Total number of types under [marketGroupId], counting types
  /// directly attached to it plus everything in any descendant group.
  /// Precomputed at load time so the browse screen can render
  /// "256 items" subtitles without recomputing on every rebuild.
  int marketGroupSubtreeCount(int marketGroupId) =>
      _marketGroupSubtreeCount[marketGroupId] ?? 0;

  /// Type IDs that have no `market_group_id` at all (skills, NPCs,
  /// blueprint copies, …). The screen shows them under an "Other" node.
  List<int> get typesWithoutMarketGroup => _typesWithoutMarketGroup;

  int? marketGroupParent(int id) => _marketGroupParent[id];

  Iterable<MapEntry<int, String>> get entries => _typeNames.entries;

  // Async richer queries.

  /// Fetches a type's localized description (default language if [lang]
  /// is null). Returns null when missing.
  Future<String?> typeDescription(int typeId, {String? lang}) async {
    return _localizedField('type_translations', 'type_id', typeId,
        'description', lang);
  }

  /// Fetches a type's localized name in [lang] (defaults to English).
  Future<String?> typeName(int typeId, {String? lang}) async {
    return _localizedField('type_translations', 'type_id', typeId, 'name', lang);
  }

  /// Searches the published types for ones that carry a given dogma
  /// effect — the ESI/SDE convention for "this module fits a high/mid/
  /// low/rig slot". Pass an empty [query] to list everything for the
  /// effect; otherwise filters by case-insensitive name substring.
  Future<List<TypeMatch>> searchTypesByEffect({
    required int effectId,
    String query = '',
    int limit = 250,
    String? lang,
    int? rigSize,
  }) async {
    final db = _db;
    if (db == null) return const [];
    final args = <Object>[lang ?? sdeDefaultLanguage, effectId];
    var sql = '''
      SELECT t.id, tt.name, t.group_id
      FROM types t
      JOIN type_dogma_effects tde ON tde.type_id = t.id
      JOIN type_translations tt
        ON tt.type_id = t.id AND tt.lang = ?
      WHERE tde.effect_id = ?
        AND t.published = 1
        AND tt.name IS NOT NULL
    ''';
    if (rigSize != null) {
      // Rigs (and other sized fittings) carry attribute 1547 = rigSize;
      // it must match the ship's rigSize. Modules without the attribute
      // are unsized (rare for rigs) and pass through.
      sql += '''
        AND (
          NOT EXISTS (
            SELECT 1 FROM type_dogma_attributes
            WHERE type_id = t.id AND attribute_id = 1547
          )
          OR EXISTS (
            SELECT 1 FROM type_dogma_attributes
            WHERE type_id = t.id AND attribute_id = 1547 AND value = ?
          )
        )
      ''';
      args.add(rigSize);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      sql += ' AND tt.name LIKE ?';
      args.add('%${q.replaceAll('%', r'\%')}%');
    }
    sql += ' ORDER BY tt.name COLLATE NOCASE LIMIT ?';
    args.add(limit);
    final rows = await db.rawQuery(sql, args);
    return [
      for (final r in rows)
        TypeMatch(
          typeId: (r['id'] as num).toInt(),
          name: r['name'] as String,
          groupId: (r['group_id'] as num?)?.toInt(),
        ),
    ];
  }

  /// Searches published types in [categoryId] (e.g. 6 for Ship). Same
  /// shape as [searchTypesByEffect] — filters by case-insensitive name
  /// substring when [query] is non-empty.
  Future<List<TypeMatch>> searchTypesByCategory({
    required int categoryId,
    String query = '',
    int limit = 250,
    String? lang,
  }) async {
    final db = _db;
    if (db == null) return const [];
    final args = <Object>[lang ?? sdeDefaultLanguage, categoryId];
    var sql = '''
      SELECT t.id, tt.name, t.group_id
      FROM types t
      JOIN groups g ON g.id = t.group_id
      JOIN type_translations tt
        ON tt.type_id = t.id AND tt.lang = ?
      WHERE g.category_id = ?
        AND t.published = 1
        AND tt.name IS NOT NULL
    ''';
    final q = query.trim();
    if (q.isNotEmpty) {
      sql += ' AND tt.name LIKE ?';
      args.add('%${q.replaceAll('%', r'\%')}%');
    }
    sql += ' ORDER BY tt.name COLLATE NOCASE LIMIT ?';
    args.add(limit);
    final rows = await db.rawQuery(sql, args);
    return [
      for (final r in rows)
        TypeMatch(
          typeId: (r['id'] as num).toInt(),
          name: r['name'] as String,
          groupId: (r['group_id'] as num?)?.toInt(),
        ),
    ];
  }

  /// Searches every published type by name substring. Used by the
  /// cargo picker, where the bucket can hold anything from ammo to
  /// spare modules — restricting by category isn't workable.
  Future<List<TypeMatch>> searchPublishedTypes({
    required String query,
    int limit = 250,
    String? lang,
  }) async {
    final db = _db;
    if (db == null) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];
    final rows = await db.rawQuery(
      '''
      SELECT t.id, tt.name, t.group_id
      FROM types t
      JOIN type_translations tt
        ON tt.type_id = t.id AND tt.lang = ?
      WHERE t.published = 1
        AND tt.name IS NOT NULL
        AND tt.name LIKE ?
      ORDER BY tt.name COLLATE NOCASE
      LIMIT ?
      ''',
      [
        lang ?? sdeDefaultLanguage,
        '%${q.replaceAll('%', r'\%')}%',
        limit,
      ],
    );
    return [
      for (final r in rows)
        TypeMatch(
          typeId: (r['id'] as num).toInt(),
          name: r['name'] as String,
          groupId: (r['group_id'] as num?)?.toInt(),
        ),
    ];
  }

  /// Per-unit packaged volume (m³) for a set of [typeIds]. Reads the
  /// `volume` column on the `types` table — same value the in-game Show
  /// Info window displays. Missing types are absent from the result map.
  Future<Map<int, double>> typeVolumes(Iterable<int> typeIds) async {
    final db = _db;
    if (db == null) return const {};
    final ids = typeIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, volume FROM types WHERE id IN ($placeholders)',
      ids,
    );
    return {
      for (final r in rows)
        if (r['volume'] != null)
          (r['id'] as num).toInt(): (r['volume'] as num).toDouble(),
    };
  }

  /// Set of dogma effect ids attached to [typeId]. Used by the fitting
  /// engine to detect modifier-flavour properties that aren't expressed
  /// as a plain attribute (e.g. `turretFitted`=42, `launcherFitted`=40).
  Future<Set<int>> typeDogmaEffectIds(int typeId) async {
    final db = _db;
    if (db == null) return const {};
    final rows = await db.query(
      'type_dogma_effects',
      columns: ['effect_id'],
      where: 'type_id = ?',
      whereArgs: [typeId],
    );
    return {for (final r in rows) (r['effect_id'] as num).toInt()};
  }

  /// All dogma attributes set on [typeId] as `attributeId → value`.
  Future<Map<int, double>> typeDogmaAttributes(int typeId) async {
    final db = _db;
    if (db == null) return const {};
    final rows = await db.query(
      'type_dogma_attributes',
      columns: ['attribute_id', 'value'],
      where: 'type_id = ?',
      whereArgs: [typeId],
    );
    return {
      for (final r in rows) r['attribute_id'] as int: (r['value'] as num).toDouble(),
    };
  }

  /// Skills required to use [typeId], in CCP's primary→senary order,
  /// resolved against the dogma attribute layout.
  Future<List<TypeRequiredSkill>> typeRequiredSkills(int typeId) async {
    const slots = [
      (skill: 182, level: 277),
      (skill: 183, level: 278),
      (skill: 184, level: 279),
      (skill: 1285, level: 1286),
      (skill: 1289, level: 1287),
      (skill: 1290, level: 1288),
    ];
    final attrs = await typeDogmaAttributes(typeId);
    final out = <TypeRequiredSkill>[];
    for (final s in slots) {
      final skillId = attrs[s.skill]?.toInt();
      final lvl = attrs[s.level]?.toInt();
      if (skillId == null || skillId == 0 || lvl == null) continue;
      out.add(TypeRequiredSkill(skillTypeId: skillId, level: lvl));
    }
    return out;
  }

  /// Trait bonuses (the blue-text lines in Show Info) for [typeId],
  /// localised to [lang]. Sorted by `(skill_type_id, importance)` so
  /// role bonuses come first and per-skill bonuses appear in the
  /// in-game display order.
  Future<List<TypeTrait>> typeTraits(int typeId, {String? lang}) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.rawQuery('''
      SELECT t.id, t.skill_type_id, t.importance, t.bonus, t.unit_id,
             tt.bonus_text
      FROM traits AS t
      LEFT OUTER JOIN trait_translations AS tt
        ON tt.trait_id = t.id AND tt.lang = ?
      WHERE t.type_id = ?
      ORDER BY
        CASE WHEN t.skill_type_id IS NULL THEN 0 ELSE 1 END,
        t.skill_type_id,
        COALESCE(t.importance, 0)
    ''', [lang ?? sdeDefaultLanguage, typeId]);
    final out = <TypeTrait>[];
    for (final r in rows) {
      final text = r['bonus_text'] as String?;
      if (text == null || text.isEmpty) continue;
      out.add(TypeTrait(
        skillTypeId: (r['skill_type_id'] as num?)?.toInt(),
        bonus: (r['bonus'] as num?)?.toDouble(),
        unitId: (r['unit_id'] as num?)?.toInt(),
        bonusText: text,
      ));
    }
    return out;
  }

  Future<String?> _localizedField(
    String table,
    String idColumn,
    int id,
    String field,
    String? lang,
  ) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      table,
      columns: [field],
      where: '$idColumn = ? AND lang = ?',
      whereArgs: [id, lang ?? sdeDefaultLanguage],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[field] as String?;
  }

  /// Reads everything we need for hot lookups into memory.
  Future<void> load() async {
    final db = _db;
    if (db == null) return;
    if (!await _hasSchema(db)) return;

    await _loadMeta(db);

    // Stored schema differs from the code's expected layout (added
    // tables, dropped columns, …) — pretend the DB is empty so the gate
    // forces a fresh import instead of crashing on missing tables.
    final stored = await _readSchemaVersion(db);
    if (stored != schemaVersion) {
      _buildNumber = null;
      _releaseDate = null;
      _installedAt = null;
      return;
    }

    _typeNames =
        await _readNameMap(db, 'type_translations', 'type_id');
    _groupNames =
        await _readNameMap(db, 'group_translations', 'group_id');
    _categoryNames =
        await _readNameMap(db, 'category_translations', 'category_id');
    _marketGroupNames = await _readNameMap(
        db, 'market_group_translations', 'market_group_id');
    _systemNames =
        await _readNameMap(db, 'solar_system_translations', 'solar_system_id');
    _stationNames =
        await _readNameMap(db, 'station_translations', 'station_id');
    _constellationNames = await _readNameMap(
        db, 'constellation_translations', 'constellation_id');
    _regionNames =
        await _readNameMap(db, 'region_translations', 'region_id');
    _factionNames =
        await _readNameMap(db, 'faction_translations', 'faction_id');
    _raceNames = await _readNameMap(db, 'race_translations', 'race_id');
    _bloodlineNames =
        await _readNameMap(db, 'bloodline_translations', 'bloodline_id');
    _npcCorporationNames = await _readNameMap(
        db, 'npc_corporation_translations', 'corporation_id');

    final attrRows = await db.query(
      'dogma_attribute_translations',
      columns: ['attribute_id', 'display_name'],
      where: 'lang = ? AND display_name IS NOT NULL',
      whereArgs: [sdeDefaultLanguage],
    );
    _attributeDisplayNames = {
      for (final r in attrRows)
        if (r['attribute_id'] is num)
          (r['attribute_id']! as num).toInt(): r['display_name'].toString(),
    };

    final attrCategoryRows = await db.query(
      'dogma_attribute_categories',
      columns: ['id', 'name'],
    );
    _attributeCategoryNames = {
      for (final r in attrCategoryRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): r['name']?.toString() ?? '',
    };

    // The `name` column is optional — older prebuilt SDE bundles
    // (everything before the column was added) don't have it. Probe
    // the table layout first and only read it when present so a
    // pre-update prebuilt still loads without crashing.
    final hasNameColumn = await _columnExists(db, 'dogma_attributes', 'name');
    final attrIdToCategory = await db.query(
      'dogma_attributes',
      columns: [
        'id',
        'category_id',
        'stackable',
        if (hasNameColumn) 'name',
      ],
    );
    _attributeCategoryByAttribute = {
      for (final r in attrIdToCategory)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['category_id'] as num?)?.toInt(),
    };
    _attributeIdByName = !hasNameColumn
        ? const {}
        : {
            for (final r in attrIdToCategory)
              if (r['id'] is num && r['name'] is String)
                r['name']! as String: (r['id']! as num).toInt(),
          };
    _attributeStackable = {
      for (final r in attrIdToCategory)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['stackable'] as num?)?.toInt() == 1,
    };

    final typeRows = await db
        .query('types', columns: ['id', 'group_id', 'market_group_id']);
    _typeGroup = {
      for (final r in typeRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['group_id'] as num?)?.toInt(),
    };

    final typesByMarketGroup = <int, List<int>>{};
    final orphanTypes = <int>[];
    for (final r in typeRows) {
      if (r['id'] is! num) continue;
      final tid = (r['id']! as num).toInt();
      final mgid = (r['market_group_id'] as num?)?.toInt();
      if (mgid == null) {
        orphanTypes.add(tid);
      } else {
        typesByMarketGroup.putIfAbsent(mgid, () => []).add(tid);
      }
    }
    _typesByMarketGroup = {
      for (final e in typesByMarketGroup.entries)
        e.key: List.unmodifiable(e.value),
    };
    _typesWithoutMarketGroup = List.unmodifiable(orphanTypes);

    final marketGroupRows =
        await db.query('market_groups', columns: ['id', 'parent_id']);
    _marketGroupParent = {
      for (final r in marketGroupRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['parent_id'] as num?)?.toInt(),
    };
    final children = <int?, List<int>>{};
    _marketGroupParent.forEach((id, parent) {
      children.putIfAbsent(parent, () => []).add(id);
    });
    _marketGroupChildren = {
      for (final e in children.entries) e.key: List.unmodifiable(e.value),
    };

    // Walk the market-group tree once to precompute total types under
    // every group (own types + everything beneath). Memoised in a map
    // so the browse screen can render counts without re-walking.
    final subtreeCount = <int, int>{};
    int countSubtree(int groupId) {
      final cached = subtreeCount[groupId];
      if (cached != null) return cached;
      var total = (_typesByMarketGroup[groupId] ?? const []).length;
      for (final child in (_marketGroupChildren[groupId] ?? const [])) {
        total += countSubtree(child);
      }
      subtreeCount[groupId] = total;
      return total;
    }

    for (final id in _marketGroupParent.keys) {
      countSubtree(id);
    }
    _marketGroupSubtreeCount = Map.unmodifiable(subtreeCount);

    final groupRows = await db.query('groups', columns: ['id', 'category_id']);
    _groupCategory = {
      for (final r in groupRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['category_id'] as num?)?.toInt(),
    };

    final typesByGroup = <int, List<int>>{};
    _typeGroup.forEach((typeId, groupId) {
      if (groupId == null) return;
      typesByGroup.putIfAbsent(groupId, () => []).add(typeId);
    });
    _typesByGroup = {
      for (final e in typesByGroup.entries) e.key: List.unmodifiable(e.value),
    };

    final groupsByCategory = <int, List<int>>{};
    _groupCategory.forEach((groupId, categoryId) {
      if (categoryId == null) return;
      groupsByCategory.putIfAbsent(categoryId, () => []).add(groupId);
    });
    _groupsByCategory = {
      for (final e in groupsByCategory.entries)
        e.key: List.unmodifiable(e.value),
    };
  }

  Future<Map<int, String>> _readNameMap(
    Database db,
    String table,
    String idColumn,
  ) async {
    final rows = await db.query(
      table,
      columns: [idColumn, 'name'],
      where: 'lang = ? AND name IS NOT NULL',
      whereArgs: [sdeDefaultLanguage],
    );
    final out = <int, String>{};
    for (final r in rows) {
      final id = r[idColumn];
      final name = r['name'];
      if (id is num && name != null) {
        out[id.toInt()] = name.toString();
      }
    }
    return out;
  }

  /// Test-only: pre-populates the hot caches without going through
  /// the SDE pipeline. Use to make `isReady` return true in widget
  /// tests that don't need real data.
  @visibleForTesting
  void seedForTesting({required Map<int, String> typeNames}) {
    _typeNames = Map.unmodifiable(typeNames);
    _buildNumber = 0;
    _installedAt = DateTime.now();
    notifyListeners();
  }

  Future<int?> _readSchemaVersion(Database db) async {
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['schema_version'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value']?.toString() ?? '');
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
  }

  Future<bool> _hasSchema(Database db) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name = 'meta'",
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _loadMeta(Database db) async {
    final rows = await db.query('meta');
    for (final r in rows) {
      final v = r['value']?.toString();
      final k = r['key']?.toString();
      if (v == null || k == null) continue;
      switch (k) {
        case 'build_number':
          _buildNumber = int.tryParse(v);
        case 'release_date':
          _releaseDate = DateTime.tryParse(v);
        case 'installed_at':
          _installedAt = DateTime.tryParse(v);
      }
    }
  }

  /// Replaces the underlying SQLite file with the freshly-imported one
  /// at [newDbPath]. Closes the live handle, atomically renames over
  /// [path], reopens, refreshes caches and notifies listeners.
  Future<void> swapTo(String newDbPath) async {
    final current = path;
    if (current == null) {
      throw StateError('TypesDatabase has no backing file to swap');
    }
    await _db?.close();
    _db = null;
    final f = File(current);
    if (await f.exists()) await f.delete();
    await File(newDbPath).rename(current);
    _db = await databaseFactory.openDatabase(
      current,
      options: OpenDatabaseOptions(readOnly: true),
    );
    await load();
    notifyListeners();
  }

  /// Wipes the local SDE: closes the handle, deletes the SQLite file,
  /// and drops all in-memory caches. After this `isReady` is false and
  /// the gate will reappear, prompting the user to download afresh.
  Future<void> reset() async {
    await _db?.close();
    _db = null;
    final current = path;
    if (current != null) {
      final f = File(current);
      if (await f.exists()) await f.delete();
    }
    _attributeIdByName = const {};
    _attributeStackable = const {};
    _typeNames = const {};
    _groupNames = const {};
    _categoryNames = const {};
    _marketGroupNames = const {};
    _systemNames = const {};
    _stationNames = const {};
    _constellationNames = const {};
    _regionNames = const {};
    _factionNames = const {};
    _raceNames = const {};
    _bloodlineNames = const {};
    _npcCorporationNames = const {};
    _attributeDisplayNames = const {};
    _attributeCategoryNames = const {};
    _attributeCategoryByAttribute = const {};
    _groupCategory = const {};
    _typeGroup = const {};
    _typesByGroup = const {};
    _groupsByCategory = const {};
    _marketGroupParent = const {};
    _marketGroupChildren = const {};
    _typesByMarketGroup = const {};
    _marketGroupSubtreeCount = const {};
    _typesWithoutMarketGroup = const [];
    _buildNumber = null;
    _releaseDate = null;
    _installedAt = null;
    notifyListeners();
  }
}
