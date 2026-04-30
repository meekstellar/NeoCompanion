import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Manifest published alongside the prebuilt SDE sqlite (one JSON file
/// per release, served from
/// `releases/latest/download/manifest.json`). The CI workflow in
/// `.github/workflows/sde-update.yml` produces it; the importer CLI
/// (`tool/build_sde.dart`) writes it.
class PrebuiltSdeManifest {
  const PrebuiltSdeManifest({
    required this.buildNumber,
    required this.releaseDate,
    required this.schemaVersion,
    required this.minimumSchemaVersion,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
  });

  final int buildNumber;
  final DateTime releaseDate;
  final int schemaVersion;
  final int minimumSchemaVersion;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;

  factory PrebuiltSdeManifest.fromJson(Map<String, dynamic> json) {
    return PrebuiltSdeManifest(
      buildNumber: (json['buildNumber'] as num).toInt(),
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      minimumSchemaVersion: (json['minimumSchemaVersion'] as num).toInt(),
      downloadUrl: json['downloadUrl'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      sha256: json['sha256'] as String,
    );
  }
}

/// Pipeline phases for the prebuilt-download path. Replaces the legacy
/// in-app import which had a heavy `importDb` phase.
enum PrebuiltSdePhase { manifest, download, extract, verify, finalize }

class PrebuiltSdeProgress {
  const PrebuiltSdeProgress({required this.phase, required this.fraction});

  final PrebuiltSdePhase phase;
  final double fraction;

  /// Single 0..1 fraction across the whole pipeline. Weights skewed to
  /// the download phase (the only meaningfully time-consuming part now
  /// that the import is done on CI).
  double get overall {
    const weights = <PrebuiltSdePhase, ({double start, double width})>{
      PrebuiltSdePhase.manifest: (start: 0.00, width: 0.02),
      PrebuiltSdePhase.download: (start: 0.02, width: 0.85),
      PrebuiltSdePhase.extract: (start: 0.87, width: 0.08),
      PrebuiltSdePhase.verify: (start: 0.95, width: 0.03),
      PrebuiltSdePhase.finalize: (start: 0.98, width: 0.02),
    };
    final w = weights[phase]!;
    return (w.start + w.width * fraction).clamp(0.0, 1.0);
  }
}

class PrebuiltSdeException implements Exception {
  const PrebuiltSdeException(this.message);
  final String message;
  @override
  String toString() => 'PrebuiltSdeException: $message';
}

/// Downloads the prebuilt SDE sqlite produced by our CI and places it at
/// `${currentDbPath}.new`. Caller (the updater) hands the file to
/// `TypesDatabase.swapTo` to publish atomically.
class PrebuiltSdeFetcher {
  PrebuiltSdeFetcher({
    required Dio dio,
    String? manifestUrl,
  })  : _dio = dio,
        _manifestUrl = manifestUrl ?? defaultManifestUrl;

  final Dio _dio;
  final String _manifestUrl;

  /// `releases/latest/download/<file>` is GitHub's auto-redirect to the
  /// most recently published (non-prerelease, non-draft) release.
  static const defaultManifestUrl =
      'https://github.com/meekstellar/NeoCompanion/releases/latest/download/manifest.json';

  Future<PrebuiltSdeManifest> fetchManifest() async {
    final res = await _dio.get<String>(
      _manifestUrl,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
      ),
    );
    final json = jsonDecode(res.data!) as Map<String, dynamic>;
    return PrebuiltSdeManifest.fromJson(json);
  }

  Stream<PrebuiltSdeProgress> run({
    required String workDir,
    required String currentDbPath,
    required int localSchemaVersion,
  }) async* {
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.manifest, fraction: 0);
    final manifest = await fetchManifest();
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.manifest, fraction: 1);

    if (localSchemaVersion < manifest.minimumSchemaVersion) {
      throw PrebuiltSdeException(
        'Manifest requires schema version ${manifest.minimumSchemaVersion} '
        'but this build uses $localSchemaVersion. Please update the app.',
      );
    }

    await Directory(workDir).create(recursive: true);
    final zipPath = p.join(workDir, 'sde-${manifest.buildNumber}.sqlite.zip');
    if (await File(zipPath).exists()) {
      await File(zipPath).delete();
    }

    yield* _download(manifest.downloadUrl, zipPath);

    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.verify, fraction: 0);
    final actualSha = await _sha256OfFile(zipPath);
    if (actualSha != manifest.sha256) {
      await File(zipPath).delete();
      throw PrebuiltSdeException(
        'sha256 mismatch on downloaded SDE archive: '
        'expected ${manifest.sha256}, got $actualSha',
      );
    }
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.verify, fraction: 1);

    final newDbPath = '$currentDbPath.new';
    if (await File(newDbPath).exists()) {
      await File(newDbPath).delete();
    }
    yield* _extract(zipPath, newDbPath);

    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.finalize, fraction: 0.5);
    try {
      await File(zipPath).delete();
    } catch (_) {}
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.finalize, fraction: 1);
  }

  Stream<PrebuiltSdeProgress> _download(String url, String dest) async* {
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

    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.download, fraction: 0);
    await for (final fraction in controller.stream) {
      yield PrebuiltSdeProgress(
          phase: PrebuiltSdePhase.download, fraction: fraction);
    }
    await future;
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.download, fraction: 1);
  }

  Stream<PrebuiltSdeProgress> _extract(String zipPath, String destDb) async* {
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.extract, fraction: 0);
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      // The archive carries one .sqlite file by convention; pick the
      // first that ends with `.sqlite` so we're tolerant of tooling that
      // adds extra metadata files.
      final entry = archive.files.firstWhere(
        (f) => f.isFile && f.name.endsWith('.sqlite'),
        orElse: () => throw const PrebuiltSdeException(
            'No .sqlite file found inside SDE archive'),
      );
      final out = OutputFileStream(destDb);
      try {
        entry.writeContent(out);
      } finally {
        await out.close();
      }
    } finally {
      await input.close();
    }
    yield const PrebuiltSdeProgress(
        phase: PrebuiltSdePhase.extract, fraction: 1);
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
}
