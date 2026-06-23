import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/result/result_page.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/models/inventory_part.dart';

class FakeRepo extends LocalRepository {
  FakeRepo() : super(testDb: null);
  @override
  Future<void> init() async {}
  @override
  Future<List<InventoryPart>> getParts(String id) async => [];
}

void main() {
  testWidgets('result page renders app bar', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => FakeRepo())],
        child: const MaterialApp(home: ResultPage(sessionId: 'test')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('零件清单'), findsOneWidget);
  });
}
