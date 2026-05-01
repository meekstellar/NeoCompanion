import 'package:sqflite_common/sqflite.dart';

import 'dto/fitting.dart';
import 'dto/local_fitting.dart';

class LocalFittingRepository {
  LocalFittingRepository(this._db);

  final Database _db;

  Future<List<LocalFitting>> listAll() async {
    final fitRows = await _db.query(
      'local_fittings',
      orderBy: 'updated_at DESC',
    );
    if (fitRows.isEmpty) return const [];
    final ids = fitRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await _db.rawQuery(
      'SELECT fitting_id, flag, type_id, quantity FROM local_fitting_items '
      'WHERE fitting_id IN ($placeholders)',
      ids,
    );
    final itemsByFit = <int, List<FittingItem>>{};
    for (final r in itemRows) {
      itemsByFit.putIfAbsent((r['fitting_id'] as num).toInt(), () => []).add(
            FittingItem(
              flag: r['flag'] as String,
              quantity: (r['quantity'] as num).toInt(),
              typeId: (r['type_id'] as num).toInt(),
            ),
          );
    }
    return [
      for (final r in fitRows) _readFit(r, itemsByFit[r['id'] as int] ?? []),
    ];
  }

  Future<LocalFitting?> get(int id) async {
    final fitRows = await _db.query(
      'local_fittings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (fitRows.isEmpty) return null;
    final itemRows = await _db.query(
      'local_fitting_items',
      where: 'fitting_id = ?',
      whereArgs: [id],
    );
    final items = [
      for (final r in itemRows)
        FittingItem(
          flag: r['flag'] as String,
          quantity: (r['quantity'] as num).toInt(),
          typeId: (r['type_id'] as num).toInt(),
        ),
    ];
    return _readFit(fitRows.first, items);
  }

  /// Inserts a new local fitting and returns its assigned id.
  Future<int> create({
    required String name,
    required String description,
    required int shipTypeId,
    List<FittingItem> items = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insert('local_fittings', {
      'name': name,
      'description': description,
      'ship_type_id': shipTypeId,
      'created_at': now,
      'updated_at': now,
    });
    for (final it in items) {
      await _db.insert('local_fitting_items', {
        'fitting_id': id,
        'flag': it.flag,
        'type_id': it.typeId,
        'quantity': it.quantity,
      });
    }
    return id;
  }

  /// Replaces the items of [id] wholesale and bumps `updated_at`. Used
  /// by the editor's autosave — the diff cost from a per-slot update
  /// path isn't worth the complexity for fits that fit in one screen.
  Future<void> updateItems(int id, List<FittingItem> items) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.update(
        'local_fittings',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'local_fitting_items',
        where: 'fitting_id = ?',
        whereArgs: [id],
      );
      for (final it in items) {
        await txn.insert('local_fitting_items', {
          'fitting_id': id,
          'flag': it.flag,
          'type_id': it.typeId,
          'quantity': it.quantity,
        });
      }
    });
  }

  Future<void> rename(int id, {String? name, String? description}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'local_fittings',
      {
        'name': ?name,
        'description': ?description,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('local_fittings', where: 'id = ?', whereArgs: [id]);
    await _db.delete(
      'local_fitting_items',
      where: 'fitting_id = ?',
      whereArgs: [id],
    );
  }

  LocalFitting _readFit(Map<String, Object?> r, List<FittingItem> items) {
    return LocalFitting(
      id: (r['id'] as num).toInt(),
      name: r['name'] as String,
      description: (r['description'] as String?) ?? '',
      shipTypeId: (r['ship_type_id'] as num).toInt(),
      items: items,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num).toInt()),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((r['updated_at'] as num).toInt()),
    );
  }
}
