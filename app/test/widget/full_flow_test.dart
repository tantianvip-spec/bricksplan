import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:brickfinder/main.dart';
import 'package:brickfinder/api/api_client.dart';

void main() {
  testWidgets('app starts and shows home page', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => ApiClient(baseUrl: 'http://test')),
        ],
        child: const BrickFinderApp(),
      ),
    );
    await tester.pump();
    expect(find.text('拍照识别'), findsOneWidget);
  });
}
