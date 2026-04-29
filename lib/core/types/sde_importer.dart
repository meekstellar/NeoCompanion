import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'types_database.dart';

/// Static-data manifest published by CCP at
/// https://developers.eveonline.com/static-data/tranquility/latest.jsonl —
/// one JSON line with the current build number.
class SdeManifest {
  const SdeManifest({required this.buildNumber, required this.releaseDate});

  final int buildNumber;
  final DateTime releaseDate;

  String get zipUrl =>
      'https://developers.eveonline.com/static-data/tranquility/'
      'eve-online-static-data-$buildNumber-jsonl.zip';
}

/// Phase of the import pipeline. The popup combines [phase] with [fraction]
/// to show one global percentage.
enum SdeImportPhase { manifest, download, extract, importDb, finalize }

class SdeImportProgress {
  const SdeImportProgress({required this.phase, required this.fraction});

  final SdeImportPhase phase;

  /// Phase-local fraction (0..1).
  final double fraction;

  /// Overall fraction across all phases, with a fixed weighting.
  double get overall {
    const weights = <SdeImportPhase, ({double start, double width})>{
      SdeImportPhase.manifest: (start: 0.00, width: 0.01),
      SdeImportPhase.download: (start: 0.01, width: 0.49),
      SdeImportPhase.extract: (start: 0.50, width: 0.05),
      SdeImportPhase.importDb: (start: 0.55, width: 0.43),
      SdeImportPhase.finalize: (start: 0.98, width: 0.02),
    };
    final w = weights[phase]!;
    return (w.start + w.width * fraction).clamp(0.0, 1.0);
  }
}

/// Files we extract from the SDE zip. Everything else is skipped to
/// keep on-device storage and import time reasonable.
const _wantedFiles = <String>[
  'types.jsonl',
  'groups.jsonl',
  'categories.jsonl',
  'marketGroups.jsonl',
  'dogmaAttributes.jsonl',
  'dogmaEffects.jsonl',
  'typeDogma.jsonl',
  'mapRegions.jsonl',
  'mapConstellations.jsonl',
  'mapSolarSystems.jsonl',
  'factions.jsonl',
  'races.jsonl',
  'bloodlines.jsonl',
];

class SdeImporter {
  SdeImporter({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _manifestUrl =
      'https://developers.eveonline.com/static-data/tranquility/latest.jsonl';

  Future<SdeManifest> fetchManifest() async {
    final res = await _dio.get<String>(
      _manifestUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final line = res.data!.trim().split('\n').first;
    final json = jsonDecode(line) as Map<String, dynamic>;
    return SdeManifest(
      buildNumber: (json['buildNumber'] as num).toInt(),
      releaseDate: DateTime.parse(json['releaseDate'] as String),
    );
  }

  /// Runs the full import pipeline. On success the new SQLite file is
  /// at `${currentDbPath}.new`; the caller should hand it to
  /// [TypesDatabase.swapTo] to publish atomically.
  Stream<SdeImportProgress> run({
    required String workDir,
    required String currentDbPath,
  }) async* {
    yield const SdeImportProgress(phase: SdeImportPhase.manifest, fraction: 0);
    final manifest = await fetchManifest();
    yield const SdeImportProgress(phase: SdeImportPhase.manifest, fraction: 1);

    await Directory(workDir).create(recursive: true);
    final zipPath = p.join(workDir, 'sde-${manifest.buildNumber}.zip');

    yield* _download(manifest.zipUrl, zipPath);
    yield* _extract(zipPath, workDir);

    final newDbPath = '$currentDbPath.new';
    if (await File(newDbPath).exists()) {
      await File(newDbPath).delete();
    }
    final db = await openDatabase(newDbPath, version: 1);
    try {
      // Speed knobs: turn off journaling/fsync for the duration of the
      // bulk import. The DB is throwaway until we rename it over the
      // live one, so a crash just means we redo the import.
      // journal_mode returns a row — must go through rawQuery on Android.
      await db.rawQuery('PRAGMA journal_mode = OFF');
      await db.execute('PRAGMA synchronous = OFF');
      await db.execute('PRAGMA temp_store = MEMORY');
      await db.execute('PRAGMA cache_size = -20000'); // ~20 MB page cache
      await createSdeSchema(db);
      yield* _importAll(db, workDir);
      await createSdeIndexes(db);
      await _writeMeta(db, manifest);
    } finally {
      await db.close();
    }

    yield const SdeImportProgress(
        phase: SdeImportPhase.finalize, fraction: 0.5);
    await _cleanup(workDir, zipPath);
    yield const SdeImportProgress(phase: SdeImportPhase.finalize, fraction: 1);
  }

  Stream<SdeImportProgress> _download(String url, String dest) async* {
    final controller = StreamController<double>();
    final future = _dio
        .download(
          url,
          dest,
          onReceiveProgress: (received, total) {
            if (total > 0) controller.add(received / total);
          },
        )
        .whenComplete(() => controller.close());

    yield const SdeImportProgress(phase: SdeImportPhase.download, fraction: 0);
    await for (final fraction in controller.stream) {
      yield SdeImportProgress(
          phase: SdeImportPhase.download, fraction: fraction);
    }
    // Surface errors (and ensure the download is fully written before
    // we move on to extraction).
    await future;
    yield const SdeImportProgress(phase: SdeImportPhase.download, fraction: 1);
  }

  Stream<SdeImportProgress> _extract(String zipPath, String workDir) async* {
    yield const SdeImportProgress(phase: SdeImportPhase.extract, fraction: 0);
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final wanted =
          archive.files.where((f) => _wantedFiles.contains(f.name)).toList();
      for (var i = 0; i < wanted.length; i++) {
        final f = wanted[i];
        final out = OutputFileStream(p.join(workDir, f.name));
        try {
          f.writeContent(out);
        } finally {
          await out.close();
        }
        yield SdeImportProgress(
          phase: SdeImportPhase.extract,
          fraction: (i + 1) / wanted.length,
        );
      }
    } finally {
      await input.close();
    }
  }

  Stream<SdeImportProgress> _importAll(Database db, String workDir) async* {
    // Per-file weights inside the importDb phase. Hand-tuned by relative
    // entry counts: types is the bulk, typeDogma also heavy.
    const weights = <String, double>{
      'types.jsonl': 0.42,
      'groups.jsonl': 0.02,
      'categories.jsonl': 0.005,
      'marketGroups.jsonl': 0.02,
      'dogmaAttributes.jsonl': 0.02,
      'dogmaEffects.jsonl': 0.02,
      'typeDogma.jsonl': 0.30,
      'mapRegions.jsonl': 0.005,
      'mapConstellations.jsonl': 0.01,
      'mapSolarSystems.jsonl': 0.10,
      'factions.jsonl': 0.005,
      'races.jsonl': 0.001,
      'bloodlines.jsonl': 0.005,
    };
    var done = 0.0;
    for (final entry in weights.entries) {
      final path = p.join(workDir, entry.key);
      if (!await File(path).exists()) {
        done += entry.value;
        yield SdeImportProgress(phase: SdeImportPhase.importDb, fraction: done);
        continue;
      }
      yield* _importFile(db, path, entry.key, entry.value, () => done)
          .map((delta) {
        done += delta;
        return SdeImportProgress(
          phase: SdeImportPhase.importDb,
          fraction: done.clamp(0.0, 1.0),
        );
      });
    }
  }

  /// Dispatches to the correct per-file importer. Yields fractional
  /// deltas of the global importDb phase as it makes progress.
  Stream<double> _importFile(
    Database db,
    String filePath,
    String name,
    double weight,
    double Function() currentDone,
  ) async* {
    final importer = _importerFor(name);
    if (importer == null) {
      yield weight;
      return;
    }
    final stream = _streamJsonlEntries(filePath);
    var lastFraction = 0.0;
    await for (final progress in importer(db, stream)) {
      final delta = (progress - lastFraction) * weight;
      lastFraction = progress;
      if (delta > 0) yield delta;
    }
    if (lastFraction < 1.0) yield (1.0 - lastFraction) * weight;
  }

  _FileImporter? _importerFor(String name) {
    switch (name) {
      case 'types.jsonl':
        return _importTypes;
      case 'groups.jsonl':
        return _importGroups;
      case 'categories.jsonl':
        return _importCategories;
      case 'marketGroups.jsonl':
        return _importMarketGroups;
      case 'dogmaAttributes.jsonl':
        return _importDogmaAttributes;
      case 'dogmaEffects.jsonl':
        return _importDogmaEffects;
      case 'typeDogma.jsonl':
        return _importTypeDogma;
      case 'mapRegions.jsonl':
        return _importRegions;
      case 'mapConstellations.jsonl':
        return _importConstellations;
      case 'mapSolarSystems.jsonl':
        return _importSolarSystems;
      case 'factions.jsonl':
        return _importFactions;
      case 'races.jsonl':
        return _importRaces;
      case 'bloodlines.jsonl':
        return _importBloodlines;
    }
    return null;
  }

  Future<void> _writeMeta(Database db, SdeManifest manifest) async {
    await db.insert('meta', {'key': 'build_number', 'value': '${manifest.buildNumber}'});
    await db.insert('meta',
        {'key': 'release_date', 'value': manifest.releaseDate.toIso8601String()});
    await db.insert('meta',
        {'key': 'installed_at', 'value': DateTime.now().toIso8601String()});
    await db.insert('meta',
        {'key': 'schema_version', 'value': '${TypesDatabase.schemaVersion}'});
  }

  Future<void> _cleanup(String workDir, String zipPath) async {
    if (await File(zipPath).exists()) await File(zipPath).delete();
    for (final name in _wantedFiles) {
      final f = File(p.join(workDir, name));
      if (await f.exists()) await f.delete();
    }
  }
}

typedef _FileImporter = Stream<double> Function(
    Database db, Stream<_JsonEntry> entries);

class _JsonEntry {
  const _JsonEntry({required this.id, required this.body});
  final int id;
  final Map<String, dynamic> body;
}

/// Streams entries from a JSONL file: one JSON object per line, with
/// the SDE convention that `_key` carries the entity id. dart:convert's
/// jsonDecode is native and noticeably faster than the pure-Dart YAML
/// parser, which is the main reason we picked the jsonl SDE variant.
Stream<_JsonEntry> _streamJsonlEntries(String path) async* {
  final lines = File(path)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final raw in lines) {
    final line = raw.endsWith('\r')
        ? raw.substring(0, raw.length - 1)
        : raw;
    if (line.isEmpty) continue;
    final entry = _parseJsonEntry(line);
    if (entry != null) yield entry;
  }
}

_JsonEntry? _parseJsonEntry(String line) {
  final doc = jsonDecode(line);
  if (doc is! Map<String, dynamic>) return null;
  final key = doc['_key'];
  final id = key is int ? key : int.tryParse(key.toString());
  if (id == null) return null;
  return _JsonEntry(id: id, body: doc);
}

// ── Per-file importers ─────────────────────────────────────────────

Stream<double> _importTypes(Database db, Stream<_JsonEntry> entries) async* {
  const total = 50000.0; // rough estimate for progress smoothing
  var processed = 0;
  Batch batch = db.batch();
  var queued = 0;

  Future<void> commitIfFull(int threshold) async {
    if (queued < threshold) return;
    await batch.commit(noResult: true);
    batch = db.batch();
    queued = 0;
  }

  await for (final e in entries) {
    final m = e.body;
    batch.insert('types', {
      'id': e.id,
      'group_id': _asInt(m['groupID']),
      'market_group_id': _asInt(m['marketGroupID']),
      'mass': _asDouble(m['mass']),
      'volume': _asDouble(m['volume']),
      'capacity': _asDouble(m['capacity']),
      'portion_size': _asInt(m['portionSize']),
      'base_price': _asDouble(m['basePrice']),
      'published': (m['published'] == true) ? 1 : 0,
    });
    queued++;
    _insertTranslations(
      batch,
      table: 'type_translations',
      idColumn: 'type_id',
      id: e.id,
      names: m['name'],
      descriptions: m['description'],
      addedRows: (n) => queued += n,
    );
    await commitIfFull(2000);
    processed++;
    if (processed % 500 == 0) {
      yield (processed / total).clamp(0.0, 0.99);
    }
  }
  if (queued > 0) await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importGroups(Database db, Stream<_JsonEntry> entries) async* {
  const total = 2200.0;
  var processed = 0;
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('groups', {
      'id': e.id,
      'category_id': _asInt(m['categoryID']),
      'published': (m['published'] == true) ? 1 : 0,
    });
    _insertTranslations(
      batch,
      table: 'group_translations',
      idColumn: 'group_id',
      id: e.id,
      names: m['name'],
    );
    processed++;
    if (processed % 200 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importCategories(
    Database db, Stream<_JsonEntry> entries) async* {
  final batch = db.batch();
  await for (final e in entries) {
    batch.insert('categories', {
      'id': e.id,
      'published': (e.body['published'] == true) ? 1 : 0,
    });
    _insertTranslations(
      batch,
      table: 'category_translations',
      idColumn: 'category_id',
      id: e.id,
      names: e.body['name'],
    );
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importMarketGroups(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 2500.0;
  var processed = 0;
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('market_groups', {
      'id': e.id,
      'parent_id': _asInt(m['parentGroupID']),
    });
    _insertTranslations(
      batch,
      table: 'market_group_translations',
      idColumn: 'market_group_id',
      id: e.id,
      names: m['name'],
      descriptions: m['description'],
    );
    processed++;
    if (processed % 200 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importDogmaAttributes(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 4000.0;
  var processed = 0;
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('dogma_attributes', {
      'id': e.id,
      'default_value': _asDouble(m['defaultValue']),
      'high_is_good': (m['highIsGood'] == true) ? 1 : 0,
      'stackable': (m['stackable'] == true) ? 1 : 0,
      'unit_id': _asInt(m['unitID']),
      'category_id': _asInt(m['categoryID']),
      'published': (m['published'] == true) ? 1 : 0,
    });
    _insertTranslations(
      batch,
      table: 'dogma_attribute_translations',
      idColumn: 'attribute_id',
      id: e.id,
      names: m['displayNameID'] ?? m['displayName'],
      descriptions: m['descriptionID'] ?? m['description'],
      nameField: 'display_name',
    );
    processed++;
    if (processed % 200 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importDogmaEffects(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 4000.0;
  var processed = 0;
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('dogma_effects', {
      'id': e.id,
      'effect_category': _asInt(m['effectCategory']),
      'published': (m['published'] == true) ? 1 : 0,
    });
    _insertTranslations(
      batch,
      table: 'dogma_effect_translations',
      idColumn: 'effect_id',
      id: e.id,
      names: m['displayNameID'] ?? m['displayName'],
      descriptions: m['descriptionID'] ?? m['description'],
      nameField: 'display_name',
    );
    processed++;
    if (processed % 200 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importTypeDogma(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 30000.0;
  var processed = 0;
  Batch batch = db.batch();
  var queued = 0;

  Future<void> flush() async {
    if (queued == 0) return;
    await batch.commit(noResult: true);
    batch = db.batch();
    queued = 0;
  }

  await for (final e in entries) {
    final attrs = e.body['dogmaAttributes'];
    if (attrs is List) {
      for (final a in attrs) {
        if (a is Map<String, dynamic>) {
          final aid = _asInt(a['attributeID']);
          final v = _asDouble(a['value']);
          if (aid != null && v != null) {
            batch.insert('type_dogma_attributes', {
              'type_id': e.id,
              'attribute_id': aid,
              'value': v,
            });
            queued++;
          }
        }
      }
    }
    final effects = e.body['dogmaEffects'];
    if (effects is List) {
      for (final ef in effects) {
        if (ef is Map<String, dynamic>) {
          final eid = _asInt(ef['effectID']);
          if (eid != null) {
            batch.insert('type_dogma_effects', {
              'type_id': e.id,
              'effect_id': eid,
              'is_default': (ef['isDefault'] == true) ? 1 : 0,
            });
            queued++;
          }
        }
      }
    }
    if (queued >= 5000) await flush();
    processed++;
    if (processed % 500 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await flush();
  yield 1.0;
}

Stream<double> _importRegions(Database db, Stream<_JsonEntry> entries) async* {
  final batch = db.batch();
  await for (final e in entries) {
    batch.insert('regions', {'id': e.id});
    _insertTranslations(
      batch,
      table: 'region_translations',
      idColumn: 'region_id',
      id: e.id,
      names: e.body['name'],
      descriptions: e.body['description'],
    );
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importConstellations(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 1100.0;
  var processed = 0;
  final batch = db.batch();
  await for (final e in entries) {
    batch.insert('constellations', {
      'id': e.id,
      'region_id': _asInt(e.body['regionID']),
    });
    _insertTranslations(
      batch,
      table: 'constellation_translations',
      idColumn: 'constellation_id',
      id: e.id,
      names: e.body['name'],
    );
    processed++;
    if (processed % 200 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importSolarSystems(
    Database db, Stream<_JsonEntry> entries) async* {
  const total = 8500.0;
  var processed = 0;
  Batch batch = db.batch();
  var queued = 0;

  Future<void> flush() async {
    if (queued == 0) return;
    await batch.commit(noResult: true);
    batch = db.batch();
    queued = 0;
  }

  await for (final e in entries) {
    final m = e.body;
    batch.insert('solar_systems', {
      'id': e.id,
      'constellation_id': _asInt(m['constellationID']),
      'region_id': _asInt(m['regionID']),
      'security': _asDouble(m['security']),
    });
    queued++;
    _insertTranslations(
      batch,
      table: 'solar_system_translations',
      idColumn: 'solar_system_id',
      id: e.id,
      names: m['name'],
      addedRows: (n) => queued += n,
    );
    if (queued >= 2000) await flush();
    processed++;
    if (processed % 500 == 0) yield (processed / total).clamp(0.0, 0.99);
  }
  await flush();
  yield 1.0;
}

Stream<double> _importFactions(
    Database db, Stream<_JsonEntry> entries) async* {
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('factions', {
      'id': e.id,
      'corporation_id': _asInt(m['corporationID']),
      'militia_corporation_id': _asInt(m['militiaCorporationID']),
      'solar_system_id': _asInt(m['solarSystemID']),
      'size_factor': _asDouble(m['sizeFactor']),
    });
    _insertTranslations(
      batch,
      table: 'faction_translations',
      idColumn: 'faction_id',
      id: e.id,
      names: m['name'],
      descriptions: m['description'],
      shortDescriptions: m['shortDescription'],
    );
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importRaces(Database db, Stream<_JsonEntry> entries) async* {
  final batch = db.batch();
  await for (final e in entries) {
    batch.insert('races', {
      'id': e.id,
      'icon_id': _asInt(e.body['iconID']),
    });
    _insertTranslations(
      batch,
      table: 'race_translations',
      idColumn: 'race_id',
      id: e.id,
      names: e.body['name'],
      descriptions: e.body['description'],
    );
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

Stream<double> _importBloodlines(
    Database db, Stream<_JsonEntry> entries) async* {
  final batch = db.batch();
  await for (final e in entries) {
    final m = e.body;
    batch.insert('bloodlines', {
      'id': e.id,
      'race_id': _asInt(m['raceID']),
      'corporation_id': _asInt(m['corporationID']),
      'charisma': _asInt(m['charisma']),
      'intelligence': _asInt(m['intelligence']),
      'memory': _asInt(m['memory']),
      'perception': _asInt(m['perception']),
      'willpower': _asInt(m['willpower']),
    });
    _insertTranslations(
      batch,
      table: 'bloodline_translations',
      idColumn: 'bloodline_id',
      id: e.id,
      names: m['name'],
      descriptions: m['description'],
      shortDescriptions: m['shortDescription'],
      maleDescriptions: m['maleDescription'],
      femaleDescriptions: m['femaleDescription'],
    );
  }
  await batch.commit(noResult: true);
  yield 1.0;
}

// ── Helpers ─────────────────────────────────────────────────────────

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Lenient string coercion. The SDE is mostly multilang `{lang: text}`
/// maps, but a handful of entries land as scalars or numbers; we don't
/// want one stray cell to abort a 50k-row import.
String? _asString(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  return null;
}

/// Inserts one row per language into a `*_translations` table. Languages
/// missing from the source map are simply not inserted (NULL on read).
void _insertTranslations(
  Batch batch, {
  required String table,
  required String idColumn,
  required int id,
  Object? names,
  Object? descriptions,
  Object? shortDescriptions,
  Object? maleDescriptions,
  Object? femaleDescriptions,
  String nameField = 'name',
  void Function(int rows)? addedRows,
}) {
  Map<String, dynamic>? asMap(Object? o) =>
      o is Map<String, dynamic> ? o : null;
  final n = asMap(names);
  final d = asMap(descriptions);
  final s = asMap(shortDescriptions);
  final mDesc = asMap(maleDescriptions);
  final fDesc = asMap(femaleDescriptions);

  for (final lang in sdeLanguages) {
    final row = <String, Object?>{idColumn: id, 'lang': lang};
    var any = false;
    final nv = _asString(n?[lang]);
    if (nv != null) {
      row[nameField] = nv;
      any = true;
    }
    final dv = _asString(d?[lang]);
    if (dv != null) {
      row['description'] = dv;
      any = true;
    }
    final sv = _asString(s?[lang]);
    if (sv != null) {
      row['short_description'] = sv;
      any = true;
    }
    final mv = _asString(mDesc?[lang]);
    if (mv != null) {
      row['male_description'] = mv;
      any = true;
    }
    final fv = _asString(fDesc?[lang]);
    if (fv != null) {
      row['female_description'] = fv;
      any = true;
    }
    if (any) {
      batch.insert(table, row);
      addedRows?.call(1);
    }
  }
}
