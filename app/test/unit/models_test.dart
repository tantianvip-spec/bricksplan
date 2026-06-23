import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/models/inventory_session.dart';
import 'package:brickfinder/models/inventory_part.dart';
import 'package:brickfinder/models/recognize_response.dart';

void main() {
  group('InventorySession', () {
    test('fromMap and toMap round-trip', () {
      final now = DateTime.now();
      final session = InventorySession(
        id: 'test-id',
        name: 'Test Session',
        createdAt: now,
        updatedAt: now,
        partCount: 5,
        thumbnail: null,
      );
      final map = session.toMap();
      final restored = InventorySession.fromMap(map);
      expect(restored.id, equals('test-id'));
      expect(restored.name, equals('Test Session'));
      expect(restored.partCount, equals(5));
    });
  });

  group('InventoryPart', () {
    test('fromMap and toMap round-trip', () {
      final part = InventoryPart(
        sessionId: 's1',
        partNum: '3001',
        colorId: 4,
        quantity: 2,
        source: 'recognized',
        confidence: 0.9,
        colorName: 'Red',
      );
      final map = part.toMap();
      final restored = InventoryPart.fromMap(map);
      expect(restored.partNum, equals('3001'));
      expect(restored.colorId, equals(4));
      expect(restored.quantity, equals(2));
    });

    test('equality based on (partNum, colorId)', () {
      final a = InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 2, source: 'recognized');
      final b = InventoryPart(sessionId: 's1', partNum: '3001', colorId: 4, quantity: 5, source: 'recognized');
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('RecognizeResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'parts': [{'part_num': '3001', 'color_id': 4, 'quantity': 2, 'confidence': 0.9}],
        'cache_hit': false,
        'low_confidence_count': 0,
      };
      final resp = RecognizeResponse.fromJson(json);
      expect(resp.parts.length, equals(1));
      expect(resp.parts[0].partNum, equals('3001'));
      expect(resp.cacheHit, isFalse);
    });
  });
}
