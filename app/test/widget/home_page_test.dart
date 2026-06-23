import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

class FakeRepo extends LocalRepository {
  FakeRepo() : super(testDb: null);
  @override
  Future<void> init() async {}
  @override
  Future<List> getAllSessions() async => [];
}

void main() {
  testWidgets('home page renders app bar', (tester) async {
    final repo = FakeRepo();
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('BrickFinder'), findsOneWidget);
  });
}
