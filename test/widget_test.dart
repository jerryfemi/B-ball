import 'package:flutter_test/flutter_test.dart';
import 'package:b_ball/main.dart';

void main() {
  testWidgets('App smoke test builds BasketballApp', (WidgetTester tester) async {
    await tester.pumpWidget(const BasketballApp());
    expect(find.byType(BasketballApp), findsOneWidget);
  });
}
