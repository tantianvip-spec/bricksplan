import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/result/result_page.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('result page shows empty state', (tester) async {
    final repo = LocalRepository(inMemory: true);
    await repo.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [Provider(create: (_) => repo)],
        child: const MaterialApp(home: ResultPage(sessionId: 'nonexistent')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('零件清单'), findsOneWidget);
  });
}
