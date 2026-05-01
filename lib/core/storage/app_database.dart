import 'package:sqflite_common/sqflite.dart';

/// Schema version of the read-write app database. Bumping triggers
/// [_migrate]; migrations are append-only.
const int kAppDbSchemaVersion = 1;

/// Opens (or creates) the writable sqflite database that holds local
/// app state — fittings, watchlists, anything that's user-authored and
/// shouldn't live in the read-only SDE.
Future<Database> openAppDatabase(String path) {
  return databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: kAppDbSchemaVersion,
      onCreate: (db, _) => _createV1(db),
      onUpgrade: (db, from, to) async {
        for (var v = from + 1; v <= to; v++) {
          await _migrate(db, v);
        }
      },
    ),
  );
}

Future<void> _createV1(Database db) async {
  await db.execute('''
CREATE TABLE local_fittings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ship_type_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
  // Drones and cargo share their slot flag (`DroneBay`, `Cargo`) but
  // can hold multiple stacks of different types — so the PK includes
  // `type_id`. Slot modules use unique `flag`s (HiSlot0, …) so this
  // doesn't constrain them.
  await db.execute('''
CREATE TABLE local_fitting_items (
  fitting_id INTEGER NOT NULL,
  flag TEXT NOT NULL,
  type_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (fitting_id, flag, type_id),
  FOREIGN KEY (fitting_id) REFERENCES local_fittings(id) ON DELETE CASCADE
)
''');
  await db.execute(
    'CREATE INDEX idx_lfi_fitting ON local_fitting_items(fitting_id)',
  );
}

Future<void> _migrate(Database db, int targetVersion) async {
  switch (targetVersion) {
    // case 2: ...
    default:
      throw StateError('No migration to v$targetVersion');
  }
}
