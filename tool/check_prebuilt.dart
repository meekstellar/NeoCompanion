// Manual smoke test for PrebuiltSdeFetcher: points the fetcher at a
// local manifest URL, runs the full pipeline, and inspects the
// resulting sqlite. Only used during development; not wired into CI.
//
// Usage:
//   python3 -m http.server 8765 --directory /tmp/sde_test &
//   dart run tool/check_prebuilt.dart http://127.0.0.1:8765/manifest.json

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:neocompanion/core/types/prebuilt_sde_fetcher.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/check_prebuilt.dart <manifest-url>');
    exit(2);
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final tmp = await Directory.systemTemp.createTemp('prebuilt_sde_check_');
  try {
    final dbPath = p.join(tmp.path, 'eve.sqlite');
    final fetcher = PrebuiltSdeFetcher(
      dio: Dio(),
      manifestUrl: args.first,
    );

    final phases = <PrebuiltSdePhase>[];
    await for (final progress in fetcher.run(
      workDir: p.join(tmp.path, 'work'),
      currentDbPath: dbPath,
      localSchemaVersion: 2,
    )) {
      if (phases.isEmpty || phases.last != progress.phase) {
        phases.add(progress.phase);
        stdout.writeln('  phase: ${progress.phase.name}');
      }
    }

    final newPath = '$dbPath.new';
    final size = await File(newPath).length();
    stdout.writeln('  extracted size: ${(size / 1024 / 1024).toStringAsFixed(1)} MB');

    final db = await databaseFactory.openDatabase(
      newPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      stdout.writeln('  tables: ${tables.length}');

      final rifter = await db.rawQuery(
          'SELECT name FROM type_translations WHERE type_id = ? AND lang = ?',
          [587, 'en']);
      stdout.writeln('  type 587 (Rifter): ${rifter.first['name']}');

      final meta = await db.rawQuery('SELECT key, value FROM meta');
      stdout.writeln('  meta:');
      for (final r in meta) {
        stdout.writeln('    ${r['key']}=${r['value']}');
      }

      final typeCount = await db
          .rawQuery('SELECT COUNT(*) AS c FROM types WHERE published = 1');
      stdout.writeln('  published types: ${typeCount.first['c']}');

      final systemCount =
          await db.rawQuery('SELECT COUNT(*) AS c FROM solar_systems');
      stdout.writeln('  solar systems: ${systemCount.first['c']}');
    } finally {
      await db.close();
    }
    stdout.writeln('OK');
  } finally {
    await tmp.delete(recursive: true);
  }
}
