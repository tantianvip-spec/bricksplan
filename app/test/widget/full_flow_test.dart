import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/main.dart';
import 'package:brickfinder/repository/local_repository.dart';
import 'package:brickfinder/api/api_client.dart';

void main() {
  testWidgets('app starts and shows home page', (tester) async {
    final repo = LocalRepository(inMemory: true);
    await repo.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => repo),
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const BrickFinderApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('历史清单'), findsOneWidget);
  });
}
