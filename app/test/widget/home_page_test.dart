import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/api/api_client.dart';

void main() {
  testWidgets('home page shows capture button', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('历史清单'), findsOneWidget);
  });
}
