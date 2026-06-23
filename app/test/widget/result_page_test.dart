import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/result/result_page.dart';
import 'package:brickfinder/api/api_client.dart';

void main() {
  testWidgets('result page shows title', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const MaterialApp(home: ResultPage(sessionId: 'nonexistent')),
      ),
    );
    await tester.pump();
    expect(find.text('零件清单'), findsOneWidget);
  });
}
