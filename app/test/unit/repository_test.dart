import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:brickfinder/models/inventory_session.dart';
import 'package:brickfinder/models/inventory_part.dart';
import 'package:brickfinder/repository/database_helper.dart' as helper;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('repository operations', () {
    test('insert and retrieve session', () async {
      final db = await helper.createDb(path: ':memory:');
      await db.insert('inventory_session', {
        'id': 's1', 'name': 'Test',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'part_count': 0,
      });
      final maps = await db.query('inventory_session');
      expect(maps.length, equals(1));
      expect(maps.first['id'], equals('s1'));
      await db.close();
    });

    test('same part_num+colorId merges quantity', () async {
      final db = await helper.createDb(path: ':memory:');
      await db.insert('inventory_session', {
        'id': 's1', 'name': 'Test',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'part_count': 0,
      });
      await db.insert('inventory_part', {
        'session_id': 's1', 'part_num': '3001', 'color_id': 4, 'quantity': 2,
        'source': 'recognized',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('inventory_part', {
        'session_id': 's1', 'part_num': '3001', 'color_id': 4, 'quantity': 3,
        'source': 'recognized',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final parts = await db.query('inventory_part');
      expect(parts.length, equals(1));
      expect(parts.first['quantity'], equals(3));
      await db.close();
    });
  });
}
