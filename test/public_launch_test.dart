import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

class PendingClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response.future;
  @override
  void close() {
    closed = true;
    if (!response.isCompleted) {
      response.complete(http.StreamedResponse(const Stream.empty(), 503));
    }
  }
}

void main() {
  final key = 'lv_pk_${'p' * 43}';
  const release = '670100000000000000000002';
  testWidgets(
    'leaving during creation closes the pending HTTP client and reports dismissal',
    (tester) async {
      BuildContext? host;
      final pending = PendingClient();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Text('Host');
            },
          ),
        ),
      );
      final result = LuliVerify.launch(
        host!,
        publishableKey: key,
        releaseId: release,
        httpClientFactory: () => pending,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('Close verification'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Leave verification'));
      await tester.pumpAndSettle();
      expect((await result).status, LuliVerifyResultStatus.dismissed);
      expect(pending.closed, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single-call native launch exchanges, executes and closes without host navigation code',
    (tester) async {
      BuildContext? host;
      final json = jsonDecode(
        File('test/fixtures/business_session.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final state = json['data'] as Map<String, dynamic>;
      state['accessChannel'] = 'native';
      state['revision'] = 2;
      final contracts = state['inputContracts'] as Map;
      final completionId = contracts.keys.firstWhere(
        (id) => contracts[id]['toolType'] == 'completion',
      ) as String;
      final seen = <http.Request>[];
      http.Client client() => MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/mobile/launches') {
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': {
                'sessionId': state['id'],
                'ticket': 'n' * 43,
                'ticketExpiresAt': '2099-01-01T00:00:00Z',
                'expiresAt': '2099-01-01T00:30:00Z',
                'accessChannel': 'native',
                'testOnly': true,
              },
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/steps')) {
          final body = jsonDecode(request.body) as Map;
          expect(body['revision'], state['revision']);
          state['revision'] = (state['revision'] as int) + 1;
          if (body['stepId'] == completionId) {
            state['status'] = 'completed';
            state['currentStep'] = null;
            state['availableSubTools'] = [];
            state['actions']['canSubmit'] = false;
          } else {
            final completion = {
              'id': completionId,
              'title': 'Finish verification',
              'description': '',
              'type': 'completion',
              'inputContract': contracts[completionId],
            };
            state['currentStep'] = completion;
            state['availableSubTools'] = [completion];
          }
        }
        final snapshot = jsonDecode(jsonEncode(json)) as Map;
        if (request.url.path.endsWith('/exchange')) {
          snapshot['data']['sessionToken'] = 's' * 43;
        }
        return http.Response(jsonEncode(snapshot), 200);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Text('Host application');
            },
          ),
        ),
      );
      final result = LuliVerify.launch(
        host!,
        publishableKey: key,
        releaseId: release,
        httpClientFactory: client,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Verification submitted'), findsOneWidget);
      await tester.tap(find.text('Return to app'));
      await tester.pumpAndSettle();
      final ended = await result;
      expect(ended.status, LuliVerifyResultStatus.completed);
      expect(ended.testOnly, true);
      expect(seen.where((r) => r.url.path.endsWith('/steps')).length, 2);
      expect(seen.first.headers['X-Publishable-Key'], key);
      for (final request in seen.skip(1)) {
        expect(request.headers.containsKey('X-Publishable-Key'), false);
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-merchant-key')),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  test('native public creation sends a scoped publishable key without private credentials or Origin', () async {
    var calls = 0;
    final data = await LuliVerifyNativeSessionTransport.createLaunch(
      config: LuliVerifyConfig(
        apiBaseUrl: Uri.parse('https://api.example.com'),
      ),
      publishableKey: key,
      releaseId: release,
      idempotencyKey: 'launch-test-001',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/mobile/launches');
        expect(request.headers['X-Publishable-Key'], key);
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('origin')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-merchant-key')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-session-token')),
        );
        expect(request.followRedirects, false);
        expect(jsonDecode(request.body), {
          'releaseId': release,
          'idempotencyKey': 'launch-test-001',
          'presentation': 'native',
          'redirectUrl': null,
        });
        return http.Response(
          jsonEncode({
            'statusCode': 200,
            'data': {
              'sessionId': '670100000000000000000003',
              'ticket': 'n' * 43,
              'ticketExpiresAt': '2099-01-01T00:00:00Z',
              'expiresAt': '2099-01-01T00:30:00Z',
              'accessChannel': 'native',
              'testOnly': true,
            },
          }),
          200,
        );
      }),
    );
    expect(calls, 1);
    expect(data['accessChannel'], 'native');
    expect(data.containsKey('publishableKey'), false);
  });
  test(
    'hosted creation requires an HTTPS return and explicit presentation',
    () async {
      final config = LuliVerifyConfig(
        apiBaseUrl: Uri.parse('https://api.example.com'),
        presentation: LuliVerifyPresentation.hostedWeb,
      );
      await expectLater(
        LuliVerifyNativeSessionTransport.createLaunch(
          config: config,
          publishableKey: key,
          releaseId: release,
          idempotencyKey: 'launch-test-001',
        ),
        throwsArgumentError,
      );
      await expectLater(
        LuliVerifyNativeSessionTransport.createLaunch(
          config: config,
          publishableKey: key,
          releaseId: release,
          idempotencyKey: 'launch-test-001',
          returnUrl: Uri.parse('http://untrusted.example'),
        ),
        throwsArgumentError,
      );
      final url = Uri.parse('https://app.example/return');
      await LuliVerifyNativeSessionTransport.createLaunch(
        config: config,
        publishableKey: key,
        releaseId: release,
        idempotencyKey: 'launch-test-001',
        returnUrl: url,
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['presentation'], 'hosted');
          expect(jsonDecode(request.body)['redirectUrl'], url.toString());
          return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': {
                'sessionId': '670100000000000000000003',
                'ticketExpiresAt': '2099-01-01T00:00:00Z',
                'expiresAt': '2099-01-01T00:30:00Z',
                'accessChannel': 'widget',
                'testOnly': true,
              },
            }),
            200,
          );
        }),
      );
    },
  );
  test('private keys and ambiguous creation failures cannot be used as public launches', () async {
    final config = LuliVerifyConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
    );
    await expectLater(
      LuliVerifyNativeSessionTransport.createLaunch(
        config: config,
        publishableKey: 'lv_sk_secret',
        releaseId: release,
        idempotencyKey: 'launch-test-001',
      ),
      throwsArgumentError,
    );
    var calls = 0;
    await expectLater(
      LuliVerifyNativeSessionTransport.createLaunch(
        config: config,
        publishableKey: key,
        releaseId: release,
        idempotencyKey: 'launch-test-001',
        client: MockClient((request) async {
          calls++;
          return http.Response('secret-provider-body', 429);
        }),
      ),
      throwsA(
        isA<LuliVerifyException>()
            .having((e) => e.code, 'code', 'rate_limited')
            .having(
              (e) => e.message,
              'message',
              isNot(contains('secret-provider-body')),
            ),
      ),
    );
    expect(calls, 1);
  });
  testWidgets(
    'one call owns its route, rejects concurrent launches and returns sanitized errors',
    (tester) async {
      BuildContext? host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold(body: Text('Merchant app'));
            },
          ),
        ),
      );
      final result = LuliVerify.launch(
        host!,
        publishableKey: 'invalid',
        releaseId: release,
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to start verification'), findsOneWidget);
      await expectLater(
        LuliVerify.launch(host!, publishableKey: key, releaseId: release),
        throwsStateError,
      );
      await tester.tap(find.text('Return to app'));
      await tester.pumpAndSettle();
      expect((await result).status, LuliVerifyResultStatus.error);
      expect(find.text('Merchant app'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cupertino hosts need no MaterialApp or merchant-authored SDK route',
    (tester) async {
      BuildContext? host;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Text('Cupertino host');
            },
          ),
        ),
      );
      final result = LuliVerify.launch(
        host!,
        publishableKey: 'invalid',
        releaseId: release,
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to start verification'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Return to app'));
      await tester.pumpAndSettle();
      expect((await result).status, LuliVerifyResultStatus.error);
      expect(tester.takeException(), isNull);
    },
  );
}
