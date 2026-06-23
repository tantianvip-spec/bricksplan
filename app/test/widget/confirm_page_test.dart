import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/confirm/confirm_page.dart';

void main() {
  testWidgets('confirm page shows buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ConfirmPage(imagePath: '/test'),
    ));
    expect(find.text('重新拍/选'), findsOneWidget);
    expect(find.text('开始识别'), findsOneWidget);
  });
}
