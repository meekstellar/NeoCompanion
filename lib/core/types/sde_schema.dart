import 'dart:io';

import 'package:sqflite_common/sqflite.dart';

/// Schema version of *our* SQLite layout (independent of CCP's SDE
/// build number). Bumping invalidates cached data and forces a re-import.
///
/// Bumps:
///   1 → 2: initial multi-language translations layout.
///   2 → 3: added `stations` + `station_translations` so NPC station
///          names (e.g. "Jita IV - Moon 4 - Caldari Navy Assembly
///          Plant") resolve locally without an ESI round-trip.
///   3 → 4: added `dogma_attribute_categories` (so the type detail
///          screen can group attributes the way the in-game Show Info
///          window does — Structure, Capacitor, Targeting, …) and
///          `traits` + `trait_translations` (the blue-text role and
///          per-skill ship bonuses).
const int kSdeSchemaVersion = 4;

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

class TypeRequiredSkill {
  const TypeRequiredSkill({required this.skillTypeId, required this.level});
  final int skillTypeId;
  final int level;
}

/// One blue-text bonus from `typeBonus.jsonl`. `skillTypeId` is null
/// for role bonuses (a flat property of the type); when set it's the
/// type id of the skill whose levels the bonus scales with.
/// `bonusText` is already localised; it can contain HTML
/// `<a href=showinfo:NNN>` links that render via `HtmlDescription`.
class TypeTrait {
  const TypeTrait({
    required this.skillTypeId,
    required this.bonus,
    required this.unitId,
    required this.bonusText,
  });

  final int? skillTypeId;
  final double? bonus;
  final int? unitId;
  final String bonusText;
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
  // Categories let the type detail screen render attributes the way
  // the in-game Show Info window does (Structure / Capacitor /
  // Targeting / …). CCP only ships English names for these.
  await db.execute('''
CREATE TABLE dogma_attribute_categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT
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

  await db.execute('''
CREATE TABLE stations (
  id INTEGER PRIMARY KEY,
  solar_system_id INTEGER NOT NULL,
  type_id INTEGER,
  owner_id INTEGER,
  operation_id INTEGER
)''');
  // Pre-composed human-readable name per language ("Jita IV - Moon 4 -
  // Caldari Navy Assembly Plant"). Building this at import time turns
  // station-name display from a network-bound `/universe/names/` POST
  // into a synchronous local lookup.
  await db.execute('''
CREATE TABLE station_translations (
  station_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT NOT NULL,
  PRIMARY KEY (station_id, lang)
)''');

  // Blue-text bonuses on ship/module info (e.g. "5% bonus to medium
  // hybrid turret damage per Caldari Frigate level"). CCP's
  // `typeBonus.jsonl` carries two flavours: `roleBonuses` (no skill —
  // a flat property of the type) and per-skill bonuses keyed by the
  // skill's typeId. We collapse both into one table with `skill_type_id`
  // null for role bonuses; `importance` controls the in-game display
  // order.
  await db.execute('''
CREATE TABLE traits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type_id INTEGER NOT NULL,
  skill_type_id INTEGER,
  importance INTEGER,
  bonus REAL,
  unit_id INTEGER
)''');
  await db.execute('''
CREATE TABLE trait_translations (
  trait_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  bonus_text TEXT NOT NULL,
  PRIMARY KEY (trait_id, lang)
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
  await db.execute(
      'CREATE INDEX idx_stations_system ON stations(solar_system_id)');
  await db.execute('CREATE INDEX idx_traits_type ON traits(type_id)');
}

/// Opens (or creates) the production SDE SQLite file. Returns null if
/// the file does not exist; callers should still construct a
/// [TypesDatabase] (it'll report `isReady = false` and force the gate).
Future<Database?> openExistingSdeDatabase(String path) async {
  if (!await File(path).exists()) return null;
  return databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true),
  );
}
