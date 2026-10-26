import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter_example/main.dart';

void main() {
  testWidgets('example consumes the local SDK package', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('LuliVerify'), findsOneWidget);
    expect(find.text('nativeUi'), findsOneWidget);
  });
}
