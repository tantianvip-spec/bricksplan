import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/result/result_page.dart';

void main() {
  testWidgets('result page shows title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResultPage(sessionId: 'test')));
    await tester.pump();
    expect(find.text('零件清单'), findsOneWidget);
  });
}
