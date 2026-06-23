import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/api/api_exceptions.dart';

void main() {
  group('ApiException', () {
    test('creates with correct code', () {
      final exc = ApiException(code: ApiError.networkError, message: 'test');
      expect(exc.code, equals(ApiError.networkError));
      expect(exc.message, equals('test'));
    });
  });
}
