import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/loading/loading_page.dart';

void main() {
  testWidgets('loading page shows recognizing text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingPage(imagePath: '/test')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('正在识别砖块…'), findsOneWidget);
  });
}
