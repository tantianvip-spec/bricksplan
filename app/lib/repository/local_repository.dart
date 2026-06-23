import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/inventory_session.dart';
import '../models/inventory_part.dart';
import 'database_helper.dart';

class LocalRepository {
  Database? _db;
  final bool inMemory;

  LocalRepository({this.inMemory = false});

  Future<void> init() async {
    if (inMemory) {
      _db = await openDatabase(path: '', inMemory: true);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, 'brickfinder.db');
      _db = await openDatabase(path: path, inMemory: false);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
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
}
