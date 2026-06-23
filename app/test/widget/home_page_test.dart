import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('home page shows capture button', (tester) async {
    final repo = LocalRepository(inMemory: true);
    await repo.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsOneWidget);
  });
}
