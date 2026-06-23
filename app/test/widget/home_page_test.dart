import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  testWidgets('home page shows capture button', (tester) async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryPath: null);
    final repo = LocalRepository(testDb: db);
    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('拍照识别'), findsOneWidget);
    await db.close();
  });
}
