import 'package:sqflite/sqflite.dart';

const String _createSessionTable = '''
CREATE TABLE IF NOT EXISTS inventory_session (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  part_count INTEGER NOT NULL DEFAULT 0,
  thumbnail TEXT
)
''';

const String _createPartTable = '''
CREATE TABLE IF NOT EXISTS inventory_part (
  session_id TEXT NOT NULL REFERENCES inventory_session(id) ON DELETE CASCADE,
  part_num TEXT NOT NULL,
  color_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL DEFAULT 'recognized',
  confidence REAL,
  color_name TEXT,
  PRIMARY KEY (session_id, part_num, color_id)
)
''';

Future<Database> openDatabase({required String path, required bool inMemory}) async {
  final db = inMemory
      ? await databaseFactoryInMemory.openDatabase(path)
      : await openDatabase(path, version: 1, onCreate: (db, version) async {
          await db.execute(_createSessionTable);
          await db.execute(_createPartTable);
        });
  if (inMemory) {
    await db.execute(_createSessionTable);
    await db.execute(_createPartTable);
  }
  return db;
}
