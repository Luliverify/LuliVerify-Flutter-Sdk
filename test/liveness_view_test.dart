import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() {
  for (final testOnly in [true, false]) {
    testWidgets(
      'liveness view ${testOnly ? 'labels simulation' : 'blocks production dummy'}',
      (tester) async {
        final json = jsonDecode(
          File('test/fixtures/liveness_session.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        json['data']['testOnly'] = testOnly;
        json['data']['sessionToken'] = 's' * 43;
        final grant = LuliVerifyNativeGrant.fromJson({
          'sessionId': '670100000000000000000003',
          'ticket': 'n' * 43,
          'ticketExpiresAt': '2099-01-01T00:00:00Z',
          'accessChannel': 'native',
        });
        final transport = await LuliVerifyNativeSessionTransport.connect(
          config: LuliVerifyConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
          grant: grant,
          client: MockClient((_) async => http.Response(jsonEncode(json), 200)),
        );
        final controller = LuliVerifySessionController(
          sessionId: grant.sessionId,
          transport: transport,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: LuliVerifySessionScreen(
              controller: controller,
              transport: transport,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Simulated liveness - test only'),
          testOnly ? findsOneWidget : findsNothing,
        );
        if (!testOnly) {
          expect(
            find.textContaining('provider that is not available'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
