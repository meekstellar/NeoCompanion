import 'package:dio/dio.dart';

import 'sde_importer.dart';
import 'types_database.dart';

/// Polls CCP's `latest.jsonl` to learn the current SDE build number,
/// compares against the locally-installed one, and answers whether the
/// app is up to date.
class TypesDatabaseChecker {
  TypesDatabaseChecker({
    required TypesDatabase database,
    Dio? dio,
  })  : _database = database,
        _importer = SdeImporter(dio: dio ?? Dio());

  final TypesDatabase _database;
  final SdeImporter _importer;

  /// `true` when the local DB matches CCP's current build, `false` when
  /// an update is available. Errors propagate so callers can keep the
  /// banner hidden on transient network failure.
  Future<bool> isFresh() async {
    final installed = _database.buildNumber;
    if (installed == null) return false;
    final manifest = await _importer.fetchManifest();
    return manifest.buildNumber <= installed;
  }
}
