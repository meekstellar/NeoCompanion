import 'package:dio/dio.dart';

import 'prebuilt_sde_fetcher.dart';
import 'types_database.dart';

/// Polls our prebuilt-SDE manifest (published by CI to GitHub Releases)
/// to learn the current build number, compares against the locally
/// installed one, and answers whether the app is up to date.
class TypesDatabaseChecker {
  TypesDatabaseChecker({
    required TypesDatabase database,
    Dio? dio,
    PrebuiltSdeFetcher? fetcher,
  })  : _database = database,
        _fetcher = fetcher ?? PrebuiltSdeFetcher(dio: dio ?? Dio());

  final TypesDatabase _database;
  final PrebuiltSdeFetcher _fetcher;

  /// `true` when the local DB matches the published manifest's build,
  /// `false` when an update is available. Errors propagate so callers
  /// can keep the banner hidden on transient network failure.
  Future<bool> isFresh() async {
    final installed = _database.buildNumber;
    if (installed == null) return false;
    final manifest = await _fetcher.fetchManifest();
    return manifest.buildNumber <= installed;
  }
}
