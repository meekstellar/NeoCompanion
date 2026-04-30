// Builds a prebaked SDE SQLite from CCP's static-data archive on a plain
// Dart VM (GitHub Actions). Reuses the importer in `lib/core/types/` so
// the schema and per-file ingestion logic stay in one place.
//
// Output (in the directory passed via --out):
//   eve-sde-<build>.sqlite        — fully imported, indexed, vacuumed
//   eve-sde-<build>.sqlite.zip    — compressed for upload
//   manifest.json                 — buildNumber, sha256, sizeBytes, …
//
// The GitHub workflow uploads both the .zip and manifest.json as
// release assets; the app fetches manifest.json from the
// `releases/latest/download/` redirect to learn what to download.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:neocompanion/core/types/sde_importer.dart';
import 'package:neocompanion/core/types/sde_schema.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> rawArgs) async {
  final parser = ArgParser()
    ..addOption('out',
        abbr: 'o',
        defaultsTo: 'build/sde',
        help: 'Output directory for the built sqlite + zip + manifest.')
    ..addOption('schema-version',
        defaultsTo: '$kSdeSchemaVersion',
        help: 'Schema version stamped into manifest.json.')
    ..addOption('minimum-schema-version',
        defaultsTo: '$kSdeSchemaVersion',
        help: 'Apps with a lower schemaVersion will refuse this manifest.')
    ..addOption('download-url-prefix',
        help: 'Optional explicit download URL prefix; if omitted, the '
            'release-asset URL is left blank and filled by the workflow.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(rawArgs);
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  // Normalize to an absolute path before doing anything else.
  // `sqflite_common_ffi` opens databases on a background isolate whose
  // current-directory isn't guaranteed to match the main isolate's, so
  // a relative `--out` like `build/sde` resolves to a different
  // location on the importer side and the rename below fails (only
  // visible on CI — running locally with an absolute --out hides it).
  final outDir = Directory(p.absolute(args['out'] as String));
  await outDir.create(recursive: true);

  // Wire FFI sqlite as the global factory so the existing importer (which
  // talks to `databaseFactory`) opens an in-process libsqlite3 instead of
  // looking for a Flutter platform channel.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dio = Dio(BaseOptions(
    headers: {'User-Agent': 'NeoCompanion-SDE-Builder'},
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 1),
  ));
  final importer = SdeImporter(dio: dio);

  stdout.writeln('==> Fetching SDE manifest from CCP');
  final manifest = await importer.fetchManifest();
  stdout.writeln('    build=${manifest.buildNumber} '
      'released=${manifest.releaseDate.toIso8601String()}');

  final workDir = p.join(outDir.path, 'work');
  await Directory(workDir).create(recursive: true);

  // The importer wants to write `${currentDbPath}.new`, so set
  // currentDbPath to a sibling that doesn't need to exist.
  final stableDbPath =
      p.join(outDir.path, 'eve-sde-${manifest.buildNumber}.sqlite');
  final newDbPath = '$stableDbPath.new';
  if (await File(newDbPath).exists()) {
    await File(newDbPath).delete();
  }
  if (await File(stableDbPath).exists()) {
    await File(stableDbPath).delete();
  }

  stdout.writeln('==> Running importer (download → extract → import)');
  final stopwatch = Stopwatch()..start();
  await for (final progress in importer.run(
    workDir: workDir,
    currentDbPath: stableDbPath,
  )) {
    final pct = (progress.overall * 100).toStringAsFixed(1);
    stdout.writeln('    [${progress.phase.name}] $pct%');
  }
  stopwatch.stop();
  stdout.writeln('    importer done in ${stopwatch.elapsed}');

  // Importer left the file at `${stableDbPath}.new`; rename to canonical.
  await File(newDbPath).rename(stableDbPath);

  stdout.writeln('==> VACUUMing and analyzing for compactness + speed');
  final db = await databaseFactory.openDatabase(stableDbPath);
  try {
    await db.execute('VACUUM');
    await db.execute('ANALYZE');
  } finally {
    await db.close();
  }

  final sqliteBytes = await File(stableDbPath).length();
  stdout.writeln('    sqlite size: ${_human(sqliteBytes)}');

  stdout.writeln('==> Compressing to .zip');
  final zipPath = '$stableDbPath.zip';
  if (await File(zipPath).exists()) {
    await File(zipPath).delete();
  }
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  await encoder.addFile(File(stableDbPath));
  await encoder.close();
  final zipBytes = await File(zipPath).length();
  stdout.writeln('    zip size: ${_human(zipBytes)} '
      '(ratio ${(zipBytes / sqliteBytes * 100).toStringAsFixed(1)}%)');

  stdout.writeln('==> Computing sha256 of zip');
  final digest = await _sha256OfFile(zipPath);
  stdout.writeln('    sha256=$digest');

  final downloadUrlPrefix = args['download-url-prefix'] as String?;
  final downloadUrl = downloadUrlPrefix == null || downloadUrlPrefix.isEmpty
      ? ''
      : '${downloadUrlPrefix.replaceAll(RegExp(r'/+$'), '')}/'
          '${p.basename(zipPath)}';

  final manifestJson = <String, Object?>{
    'buildNumber': manifest.buildNumber,
    'releaseDate': manifest.releaseDate.toIso8601String(),
    'schemaVersion': int.parse(args['schema-version'] as String),
    'minimumSchemaVersion':
        int.parse(args['minimum-schema-version'] as String),
    'downloadUrl': downloadUrl,
    'fileName': p.basename(zipPath),
    'sizeBytes': zipBytes,
    'sqliteSizeBytes': sqliteBytes,
    'sha256': digest,
  };
  final manifestPath = p.join(outDir.path, 'manifest.json');
  await File(manifestPath)
      .writeAsString(const JsonEncoder.withIndent('  ').convert(manifestJson));
  stdout.writeln('==> Wrote $manifestPath');

  // Cleanup workdir (extracted JSONLs, downloaded zip).
  try {
    await Directory(workDir).delete(recursive: true);
  } catch (_) {}

  stdout.writeln('==> Done.');
}

Future<String> _sha256OfFile(String path) async {
  final sink = AccumulatorSink<Digest>();
  final hasher = sha256.startChunkedConversion(sink);
  await for (final chunk in File(path).openRead()) {
    hasher.add(chunk);
  }
  hasher.close();
  return sink.events.single.toString();
}

String _human(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
