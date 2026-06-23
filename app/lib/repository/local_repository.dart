import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/inventory_session.dart';
import '../models/inventory_part.dart';
import 'database_helper.dart' as helper;

class LocalRepository {
  Database? _db;
  final Database? _testDb;

  LocalRepository({Database? testDb}) : _testDb = testDb;

  Future<void> init() async {
    if (_testDb != null) {
      _db = _testDb;
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'brickfinder.db');
    _db = await helper.createDb(path: path);
  }

  Database get _database {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  Future<List<InventorySession>> getAllSessions() async {
    final maps = await _database.query('inventory_session', orderBy: 'created_at DESC');
    return maps.map(InventorySession.fromMap).toList();
  }

  Future<InventorySession?> getSession(String id) async {
    final maps = await _database.query('inventory_session', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return InventorySession.fromMap(maps.first);
  }

  Future<void> insertSession(InventorySession session) async {
    await _database.insert('inventory_session', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(InventorySession session) async {
    await _database.update('inventory_session', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> deleteSession(String id) async {
    await _database.delete('inventory_session', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InventoryPart>> getParts(String sessionId) async {
    final maps = await _database.query('inventory_part',
        where: 'session_id = ?', whereArgs: [sessionId]);
    return maps.map(InventoryPart.fromMap).toList();
  }

  Future<void> insertPart(InventoryPart part) async {
    await _database.insert('inventory_part', part.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePart(InventoryPart part) async {
    await _database.update(
      'inventory_part',
      part.toMap(),
      where: 'session_id = ? AND part_num = ? AND color_id = ?',
      whereArgs: [part.sessionId, part.partNum, part.colorId],
    );
  }

  Future<void> deletePart(String sessionId, String partNum, int colorId) async {
    await _database.delete(
      'inventory_part',
      where: 'session_id = ? AND part_num = ? AND color_id = ?',
      whereArgs: [sessionId, partNum, colorId],
    );
  }

  Future<void> deleteAllParts(String sessionId) async {
    await _database.delete('inventory_part',
        where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
