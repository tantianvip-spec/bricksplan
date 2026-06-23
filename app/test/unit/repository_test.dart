import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/models/inventory_session.dart';
import 'package:brickfinder/models/inventory_part.dart';

void main() {
  late LocalRepository repo;

  setUp(() async {
    repo = LocalRepository(inMemory: true);
    await repo.init();
  });

  tearDown(() async {
    await repo.close();
  });

  group('sessions', () {
    test('insert and retrieve session', () async {
      final session = InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      await repo.insertSession(session);
      final sessions = await repo.getAllSessions();
      expect(sessions.length, equals(1));
      expect(sessions.first.id, equals('s1'));
    });

    test('getSession returns null for missing', () async {
      final session = await repo.getSession('nonexistent');
      expect(session, isNull);
    });
  });

  group('parts', () {
    test('insert and retrieve parts', () async {
      await repo.insertSession(InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3003', colorId: 4, quantity: 1));
      final parts = await repo.getParts('s1');
      expect(parts.length, equals(2));
    });

    test('same part_num+colorId merges quantity', () async {
      await repo.insertSession(InventorySession(
        id: 's1', name: 'Test', createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2));
      await repo.insertPart(InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 3));
      final parts = await repo.getParts('s1');
      expect(parts.length, equals(1));
      expect(parts.first.quantity, equals(5));
    });
  });
}
