import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:brickfinder/pages/capture/capture_page.dart';

void main() {
  testWidgets('capture page shows both buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CapturePage()));
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
  });
}
