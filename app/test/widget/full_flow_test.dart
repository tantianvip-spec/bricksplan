import 'package:flutter_test/flutter_test.dart';
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('app starts and shows title', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => FakeRepo())],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('BrickFinder'), findsOneWidget);
  });
}
