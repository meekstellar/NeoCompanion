import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqflite.dart';

import 'sde_schema.dart';
export 'sde_schema.dart'
    show
        kSdeSchemaVersion,
        sdeLanguages,
        sdeDefaultLanguage,
        TypeRequiredSkill,
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

  Map<int, int?> _groupCategory = const {};
  Map<int, int?> _typeGroup = const {};
  Map<int, List<int>> _typesByGroup = const {};
  Map<int, List<int>> _groupsByCategory = const {};
  Map<int, int?> _marketGroupParent = const {};
  Map<int?, List<int>> _marketGroupChildren = const {};
  Map<int, List<int>> _typesByMarketGroup = const {};
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
    _groupCategory = const {};
    _typeGroup = const {};
    _typesByGroup = const {};
    _groupsByCategory = const {};
    _marketGroupParent = const {};
    _marketGroupChildren = const {};
    _typesByMarketGroup = const {};
    _typesWithoutMarketGroup = const [];
    _buildNumber = null;
    _releaseDate = null;
    _installedAt = null;
    notifyListeners();
  }
}
