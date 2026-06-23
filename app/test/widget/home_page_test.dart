import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/models/inventory_session.dart';

class FakeRepo extends LocalRepository {
  FakeRepo() : super(testDb: null);
  @override
  Future<void> init() async {}
  @override
  Future<List<InventorySession>> getAllSessions() async => [];
}

Widget buildTestWidget({LocalRepository? repo}) {
  return MultiProvider(
    providers: [Provider(create: (_) => repo ?? FakeRepo())],
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  testWidgets('home page renders app bar', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump();
    expect(find.text('BrickFinder'), findsOneWidget);
  });
}
