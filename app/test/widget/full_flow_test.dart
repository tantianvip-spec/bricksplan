import 'package:flutter_test/flutter_test.dart';
import 'package:brickfinder/main.dart';

void main() {
  testWidgets('app starts and shows home page', (tester) async {
    await tester.pumpWidget(const BrickFinderApp());
    await tester.pump();
    expect(find.text('BrickFinder'), findsOneWidget);
  });
}
