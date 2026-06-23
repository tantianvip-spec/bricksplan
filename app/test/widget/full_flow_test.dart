import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/pages/home/home_page.dart';
import 'package:brickfinder/api/api_client.dart';
import 'package:brickfinder/repository/local_repository.dart';

void main() {
  testWidgets('app starts and shows home page', (tester) async {
    final repo = LocalRepository();
    await repo.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => repo),
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    expect(find.text('拍照识别'), findsOneWidget);
  });
}
