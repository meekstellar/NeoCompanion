import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'sde_importer.dart';
import 'types_database.dart';

/// Single-percentage progress event surfaced to the UI.
class TypesDatabaseProgress {
  const TypesDatabaseProgress(this.fraction);

  /// Overall completion 0..1.
  final double fraction;
}

/// Drives a full SDE refresh: downloads the latest archive from CCP,
/// imports the relevant YAMLs into a sibling SQLite file, and swaps it
/// over the live one. Emits [TypesDatabaseProgress] for the popup.
class TypesDatabaseUpdater {
  TypesDatabaseUpdater({
    required Dio dio,
    required TypesDatabase database,
  })  : _importer = SdeImporter(dio: dio),
        _database = database;

  final SdeImporter _importer;
  final TypesDatabase _database;

  Stream<TypesDatabaseProgress> update() async* {
    final dbPath = _database.path;
    if (dbPath == null) {
      throw StateError(
          'TypesDatabase has no backing file; cannot import SDE in tests');
    }
    final workDir = p.join(p.dirname(dbPath), 'sde_work');
    await Directory(workDir).create(recursive: true);

    await for (final progress in _importer.run(
      workDir: workDir,
      currentDbPath: dbPath,
    )) {
      yield TypesDatabaseProgress(progress.overall);
    }

    await _database.swapTo('$dbPath.new');
    yield const TypesDatabaseProgress(1);
  }
}
