import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/api/api_client.dart';
import 'package:brickfinder/api/api_exceptions.dart';

void main() {
  group('ApiClient', () {
    test('recognize with non-existent file throws', () async {
      final client = ApiClient(baseUrl: 'http://test');
      expect(
        () => client.recognize(imagePath: '/nonexistent.jpg'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
