import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

LuliVerifyInputContract contract() {
  final session = LuliVerifySession.fromResponse(
    jsonDecode(File('test/fixtures/business_session.json').readAsStringSync()),
  );
  return session.contracts.values.firstWhere((item) => item.toolType == 'cac');
}

void main() {
  testWidgets(
    'renders backend labels, rejects missing fields, and submits defaults',
    (tester) async {
      Map<String, Object?>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LuliVerifyContractForm(
                  contract: contract(),
                  onSubmit: (input) async {
                    submitted = input;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Company registration number'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(submitted, isNull);
      await tester.enterText(find.byType(TextFormField).at(0), 'RC123456');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Example Company',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'registrationNumber': 'RC123456',
        'companyName': 'Example Company',
        'detailLevel': 'basic',
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('disabled forms do not submit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LuliVerifyContractForm(
            contract: contract(),
            enabled: false,
            onSubmit: (_) async {
              calls++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(calls, 0);
  });
  testWidgets('native form remains within a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LuliVerifyContractForm(
                contract: contract(),
                onSubmit: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
