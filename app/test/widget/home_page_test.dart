import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/home/home_page.dart';

void main() {
  testWidgets('home page shows capture button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('历史清单'), findsOneWidget);
  });
}
