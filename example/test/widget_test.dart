import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter_example/main.dart';

void main() {
  testWidgets(
    'example accepts publishable key and release without merchant secrets',
    (tester) async {
      await tester.pumpWidget(const ExampleApp());
      expect(find.text('LuliVerify'), findsOneWidget);
      expect(find.text('Publishable key'), findsOneWidget);
      expect(find.text('Published workflow ID'), findsOneWidget);
      expect(find.text('Start verification'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
