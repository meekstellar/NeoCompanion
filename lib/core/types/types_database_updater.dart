import 'dart:math' as math;

import '../../features/characters/data/character_repository.dart';
import '../network/esi_client.dart';
import 'types_database.dart';

class TypesDatabaseProgress {
  const TypesDatabaseProgress({
    required this.phase,
    required this.current,
    required this.total,
  });

  final String phase;
  final int current;
  final int total;

  double get fraction => total == 0 ? 0 : current / total;
}

/// Walks ESI to populate [TypesDatabase]:
/// 1. /universe/types/?page=N — collect every type id (paginated)
/// 2. /universe/names/ in batches of [_chunkSize] — resolve to names
///
/// Yields one [TypesDatabaseProgress] per network step so the UI can
/// render a progress bar with phase labels. The DB is committed in one
/// shot at the end so partial updates don't replace the previous good
/// state if the user cancels mid-flight.
class TypesDatabaseUpdater {
  TypesDatabaseUpdater({
    required EsiClient esi,
    required CharacterRepository character,
    required TypesDatabase database,
  })  : _esi = esi,
        _character = character,
        _database = database;

  final EsiClient _esi;
  final CharacterRepository _character;
  final TypesDatabase _database;

  static const int _chunkSize = 1000;

  Stream<TypesDatabaseProgress> update() async* {
    final ids = <int>[];
    var page = 1;
    var totalPages = 1;
    String? firstPageEtag;
    while (true) {
      final res = await _esi.get<List<dynamic>>(
        '/universe/types/',
        queryParameters: {'page': page},
      );
      ids.addAll(res.data!.cast<int>());
      totalPages = int.tryParse(res.headers.value('x-pages') ?? '1') ?? 1;
      if (page == 1) firstPageEtag = res.headers.value('etag');
      yield TypesDatabaseProgress(
        phase: 'Fetching type IDs',
        current: page,
        total: totalPages,
      );
      if (page >= totalPages) break;
      page++;
    }

    final chunkCount = (ids.length / _chunkSize).ceil();
    final names = <int, String>{};
    for (var i = 0; i < chunkCount; i++) {
      final start = i * _chunkSize;
      final end = math.min(start + _chunkSize, ids.length);
      final chunk = ids.sublist(start, end);
      final resolved = await _character.resolveNames(chunk);
      for (final n in resolved) {
        names[n.id] = n.name;
      }
      yield TypesDatabaseProgress(
        phase: 'Resolving names',
        current: i + 1,
        total: chunkCount,
      );
    }

    await _database.commit(
      names: names,
      firstPageEtag: firstPageEtag,
      pageCount: totalPages,
    );
    yield TypesDatabaseProgress(
      phase: 'Done',
      current: chunkCount,
      total: chunkCount,
    );
  }
}
