import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/loading/loading_page.dart';
import 'package:brickfinder/api/api_client.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('loading page shows recognizing text', (tester) async {
    final repo = LocalRepository();
    await repo.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => repo),
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const MaterialApp(home: LoadingPage(imagePath: '/test')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('正在识别砖块…'), findsOneWidget);
  });
}
