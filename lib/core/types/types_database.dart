import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// All EVE SDE languages we ingest. Stored as ISO-639-1 codes in the
/// `*_translations` tables.
const sdeLanguages = <String>[
  'en',
  'ru',
];

/// Default UI language. Hot-cached lookups (type names, group names…)
/// are populated for this language at load time; other languages are
/// queried on demand.
const sdeDefaultLanguage = 'en';

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
  /// re-import through the gate.
  static const int schemaVersion = 2;

  Database? _db;

  Map<int, String> _typeNames = const {};
  Map<int, String> _groupNames = const {};
  Map<int, String> _categoryNames = const {};
  Map<int, String> _marketGroupNames = const {};
  Map<int, String> _systemNames = const {};
  Map<int, String> _constellationNames = const {};
  Map<int, String> _regionNames = const {};
  Map<int, String> _factionNames = const {};
  Map<int, String> _raceNames = const {};
  Map<int, String> _bloodlineNames = const {};
  Map<int, String> _npcCorporationNames = const {};
  Map<int, String> _attributeDisplayNames = const {};

  Map<int, int?> _groupCategory = const {};
  Map<int, int?> _typeGroup = const {};

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
  String? lookupConstellation(int id) => _constellationNames[id];
  String? lookupRegion(int id) => _regionNames[id];
  String? lookupFaction(int id) => _factionNames[id];
  String? lookupRace(int id) => _raceNames[id];
  String? lookupBloodline(int id) => _bloodlineNames[id];
  String? lookupNpcCorporation(int id) => _npcCorporationNames[id];
  String? lookupAttributeName(int attributeId) =>
      _attributeDisplayNames[attributeId];

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

    final typeRows = await db.query('types', columns: ['id', 'group_id']);
    _typeGroup = {
      for (final r in typeRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['group_id'] as num?)?.toInt(),
    };
    final groupRows = await db.query('groups', columns: ['id', 'category_id']);
    _groupCategory = {
      for (final r in groupRows)
        if (r['id'] is num)
          (r['id']! as num).toInt(): (r['category_id'] as num?)?.toInt(),
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
    _db = await openDatabase(current, readOnly: true);
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
    _constellationNames = const {};
    _regionNames = const {};
    _factionNames = const {};
    _raceNames = const {};
    _bloodlineNames = const {};
    _npcCorporationNames = const {};
    _attributeDisplayNames = const {};
    _groupCategory = const {};
    _typeGroup = const {};
    _buildNumber = null;
    _releaseDate = null;
    _installedAt = null;
    notifyListeners();
  }
}

class TypeRequiredSkill {
  const TypeRequiredSkill({required this.skillTypeId, required this.level});
  final int skillTypeId;
  final int level;
}

/// Creates the SQLite tables we import the SDE into (no indexes — those
/// are added by [createSdeIndexes] after bulk insert finishes, which is
/// noticeably faster than maintaining them during the import).
Future<void> createSdeSchema(Database db) async {
  await db.execute('''
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT
)''');
  await db.execute('''
CREATE TABLE types (
  id INTEGER PRIMARY KEY,
  group_id INTEGER,
  market_group_id INTEGER,
  mass REAL,
  volume REAL,
  capacity REAL,
  portion_size INTEGER,
  base_price REAL,
  published INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute('''
CREATE TABLE type_translations (
  type_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  PRIMARY KEY (type_id, lang)
)''');

  await db.execute('''
CREATE TABLE groups (
  id INTEGER PRIMARY KEY,
  category_id INTEGER,
  published INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute('''
CREATE TABLE group_translations (
  group_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  PRIMARY KEY (group_id, lang)
)''');

  await db.execute('''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY,
  published INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute('''
CREATE TABLE category_translations (
  category_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  PRIMARY KEY (category_id, lang)
)''');

  await db.execute('''
CREATE TABLE market_groups (
  id INTEGER PRIMARY KEY,
  parent_id INTEGER
)''');
  await db.execute('''
CREATE TABLE market_group_translations (
  market_group_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  PRIMARY KEY (market_group_id, lang)
)''');

  await db.execute('''
CREATE TABLE dogma_attributes (
  id INTEGER PRIMARY KEY,
  default_value REAL,
  high_is_good INTEGER,
  stackable INTEGER,
  unit_id INTEGER,
  category_id INTEGER,
  published INTEGER
)''');
  await db.execute('''
CREATE TABLE dogma_attribute_translations (
  attribute_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  display_name TEXT,
  description TEXT,
  PRIMARY KEY (attribute_id, lang)
)''');

  await db.execute('''
CREATE TABLE dogma_effects (
  id INTEGER PRIMARY KEY,
  effect_category INTEGER,
  published INTEGER
)''');
  await db.execute('''
CREATE TABLE dogma_effect_translations (
  effect_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  display_name TEXT,
  description TEXT,
  PRIMARY KEY (effect_id, lang)
)''');

  await db.execute('''
CREATE TABLE type_dogma_attributes (
  type_id INTEGER NOT NULL,
  attribute_id INTEGER NOT NULL,
  value REAL NOT NULL,
  PRIMARY KEY (type_id, attribute_id)
)''');

  await db.execute('''
CREATE TABLE type_dogma_effects (
  type_id INTEGER NOT NULL,
  effect_id INTEGER NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (type_id, effect_id)
)''');

  await db.execute('''
CREATE TABLE regions (
  id INTEGER PRIMARY KEY
)''');
  await db.execute('''
CREATE TABLE region_translations (
  region_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  PRIMARY KEY (region_id, lang)
)''');

  await db.execute('''
CREATE TABLE constellations (
  id INTEGER PRIMARY KEY,
  region_id INTEGER
)''');
  await db.execute('''
CREATE TABLE constellation_translations (
  constellation_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  PRIMARY KEY (constellation_id, lang)
)''');

  await db.execute('''
CREATE TABLE solar_systems (
  id INTEGER PRIMARY KEY,
  constellation_id INTEGER,
  region_id INTEGER,
  security REAL
)''');
  await db.execute('''
CREATE TABLE solar_system_translations (
  solar_system_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  PRIMARY KEY (solar_system_id, lang)
)''');

  await db.execute('''
CREATE TABLE factions (
  id INTEGER PRIMARY KEY,
  corporation_id INTEGER,
  militia_corporation_id INTEGER,
  solar_system_id INTEGER,
  size_factor REAL
)''');
  await db.execute('''
CREATE TABLE faction_translations (
  faction_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  short_description TEXT,
  PRIMARY KEY (faction_id, lang)
)''');

  await db.execute('''
CREATE TABLE races (
  id INTEGER PRIMARY KEY,
  icon_id INTEGER
)''');
  await db.execute('''
CREATE TABLE race_translations (
  race_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  PRIMARY KEY (race_id, lang)
)''');

  await db.execute('''
CREATE TABLE bloodlines (
  id INTEGER PRIMARY KEY,
  race_id INTEGER,
  corporation_id INTEGER,
  charisma INTEGER,
  intelligence INTEGER,
  memory INTEGER,
  perception INTEGER,
  willpower INTEGER
)''');
  await db.execute('''
CREATE TABLE bloodline_translations (
  bloodline_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  short_description TEXT,
  male_description TEXT,
  female_description TEXT,
  PRIMARY KEY (bloodline_id, lang)
)''');

  await db.execute('''
CREATE TABLE npc_corporations (
  id INTEGER PRIMARY KEY,
  ticker TEXT,
  ceo_id INTEGER,
  faction_id INTEGER,
  station_id INTEGER,
  size TEXT,
  extent TEXT,
  tax_rate REAL
)''');
  await db.execute('''
CREATE TABLE npc_corporation_translations (
  corporation_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT,
  description TEXT,
  PRIMARY KEY (corporation_id, lang)
)''');
}

/// Creates the secondary indexes after the bulk import is complete.
/// Building them in one pass at the end is significantly faster than
/// maintaining them while millions of rows stream in.
Future<void> createSdeIndexes(Database db) async {
  await db.execute('CREATE INDEX idx_types_group ON types(group_id)');
  await db.execute(
      'CREATE INDEX idx_types_market_group ON types(market_group_id)');
  await db.execute(
      'CREATE INDEX idx_tt_name ON type_translations(lang, name COLLATE NOCASE)');
  await db.execute('CREATE INDEX idx_groups_category ON groups(category_id)');
  await db.execute(
      'CREATE INDEX idx_tda_type ON type_dogma_attributes(type_id)');
}

/// Opens (or creates) the production SDE SQLite file. Returns null if
/// the file does not exist; callers should still construct a
/// [TypesDatabase] (it'll report `isReady = false` and force the gate).
Future<Database?> openExistingSdeDatabase(String path) async {
  if (!await File(path).exists()) return null;
  return openDatabase(path, readOnly: true);
}
