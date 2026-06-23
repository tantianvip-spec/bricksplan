import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  testWidgets('home page renders', (tester) async {
    final db = await databaseFactoryFfi.openDatabase('');
    final repo = LocalRepository(testDb: db);
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    // Pump enough frames for async load to complete
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('BrickFinder'), findsOneWidget);
    await db.close();
  });
}
