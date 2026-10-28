import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

class CallbackBrowser extends UrlLauncherPlatform {
  bool opened = false;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened = true;
    return true;
  }
}

void main() {
  testWidgets(
    'a matching app-link event closes hosted SDK and returns navigation result',
    (tester) async {
      final browser = CallbackBrowser();
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = browser;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      const events = MethodChannel('com.llfbandit.app_links/events');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        events,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          events,
          null,
        ),
      );
      BuildContext? host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Text('Merchant app');
            },
          ),
        ),
      );
      final result = LuliVerify.launch(
        host!,
        publishableKey: 'lv_pk_${'p' * 43}',
        releaseId: '670100000000000000000002',
        mode: LuliVerifyPresentation.hostedWeb,
        returnUrl: Uri.parse(
          'https://merchant.example/verification-return?state=expected',
        ),
        httpClientFactory: () => MockClient((request) async {
          expect(jsonDecode(request.body)['presentation'], 'hosted');
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': {
                'sessionId': '670100000000000000000003',
                'ticketExpiresAt': '2099-01-01T00:00:00Z',
                'expiresAt': '2099-01-01T01:00:00Z',
                'accessChannel': 'widget',
                'testOnly': true,
                'launchUrl':
                    'https://verify.luliverify.io/#sessionId=670100000000000000000003&ticket=${'t' * 43}',
              },
            }),
            200,
          );
        }),
      );
      await tester.pumpAndSettle();
      expect(browser.opened, true);
      expect(find.text('Continue in your browser'), findsOneWidget);
      void incoming(String url) => tester.binding.channelBuffers.push(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(url),
        (_) {},
      );
      incoming('https://merchant.example/verification-return?state=wrong');
      await tester.pumpAndSettle();
      expect(find.text('Continue in your browser'), findsOneWidget);
      incoming('https://merchant.example/verification-return?state=expected');
      await tester.pumpAndSettle();
      final returned = await result;
      expect(returned.status, LuliVerifyResultStatus.hostedReturned);
      expect(returned.status, isNot(LuliVerifyResultStatus.completed));
      expect(returned.sessionId, '670100000000000000000003');
      expect(find.text('Merchant app'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
