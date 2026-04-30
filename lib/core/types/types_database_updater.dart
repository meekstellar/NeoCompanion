import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'prebuilt_sde_fetcher.dart';
import 'types_database.dart';

/// Single-percentage progress event surfaced to the UI.
class TypesDatabaseProgress {
  const TypesDatabaseProgress(this.fraction);

  /// Overall completion 0..1.
  final double fraction;
}

/// Drives a full SDE refresh: pulls the prebuilt SQLite produced by our
/// CI from the GitHub Releases CDN, verifies sha256, extracts it next to
/// the live DB, and swaps. The on-device YAML→SQLite import that used to
/// live here is now done once on CI; see `tool/build_sde.dart`.
class TypesDatabaseUpdater {
  TypesDatabaseUpdater({
    required Dio dio,
    required TypesDatabase database,
    PrebuiltSdeFetcher? fetcher,
  })  : _fetcher = fetcher ?? PrebuiltSdeFetcher(dio: dio),
        _database = database;

  final PrebuiltSdeFetcher _fetcher;
  final TypesDatabase _database;

  Stream<TypesDatabaseProgress> update() async* {
    final dbPath = _database.path;
    if (dbPath == null) {
      throw StateError(
          'TypesDatabase has no backing file; cannot import SDE in tests');
    }
    final workDir = p.join(p.dirname(dbPath), 'sde_work');
    await Directory(workDir).create(recursive: true);

    await for (final progress in _fetcher.run(
      workDir: workDir,
      currentDbPath: dbPath,
      localSchemaVersion: kSdeSchemaVersion,
    )) {
      yield TypesDatabaseProgress(progress.overall);
    }

    await _database.swapTo('$dbPath.new');
    yield const TypesDatabaseProgress(1);
  }
}
