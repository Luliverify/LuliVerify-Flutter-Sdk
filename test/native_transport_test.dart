import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Map<String, dynamic> response({int revision = 1}) {
  final json = jsonDecode(
    File('test/fixtures/business_session.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  json['data']['accessChannel'] = 'native';
  json['data']['sessionToken'] = 't' * 43;
  json['data']['revision'] = revision;
  return json;
}

LuliVerifyNativeGrant grant() => LuliVerifyNativeGrant.fromJson({
  'sessionId': '670100000000000000000003',
  'ticket': 'a' * 43,
  'ticketExpiresAt': '2099-01-01T00:00:00Z',
  'accessChannel': 'native',
});
final config = LuliVerifyConfig(
  apiBaseUrl: Uri.parse('https://api.example.com'),
);

void main() {
  test('exchanges once, sends only native session credentials and strips public tokens', () async {
    final seen = <http.Request>[];
    final transport = await LuliVerifyNativeSessionTransport.connect(
      config: config,
      grant: grant(),
      client: MockClient((request) async {
        seen.add(request);
        return http.Response(jsonEncode(response()), 200);
      }),
    );
    addTearDown(transport.dispose);
    await transport.read();
    expect(
      seen[0].url.path,
      '/mobile-sessions/670100000000000000000003/exchange',
    );
    expect(seen[0].headers.containsKey('X-Session-Token'), false);
    expect(seen[1].headers['X-Session-Token'], 't' * 43);
    for (final request in seen) {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('origin')),
      );
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('x-merchant-key')),
      );
      expect(request.followRedirects, false);
    }
    expect(transport.initialSession.raw.containsKey('sessionToken'), false);
  });
  test('does not retry HTTP failures or expose server payloads', () async {
    var calls = 0;
    await expectLater(
      LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: grant(),
        client: MockClient((_) async {
          calls++;
          return http.Response('sensitive-provider-payload', 409);
        }),
      ),
      throwsA(
        isA<LuliVerifyException>()
            .having((e) => e.code, 'code', 'conflict')
            .having(
              (e) => e.message,
              'message',
              isNot(contains('sensitive-provider-payload')),
            ),
      ),
    );
    expect(calls, 1);
  });
  test('rejects a redirect rather than forwarding credentials', () async {
    await expectLater(
      LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: grant(),
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example'},
          ),
        ),
      ),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('a consumed grant is not reused after an ambiguous exchange', () async {
    final value = grant();
    await expectLater(
      LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: value,
        client: MockClient((_) async => throw Exception('secret')),
      ),
      throwsA(isA<LuliVerifyException>()),
    );
    await expectLater(
      LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: value,
        client: MockClient((_) async => http.Response('', 200)),
      ),
      throwsA(
        isA<LuliVerifyException>().having(
          (e) => e.code,
          'code',
          'grant_expired',
        ),
      ),
    );
  });
  test('rejects a widget response on the native channel', () async {
    final json = response();
    json['data']['accessChannel'] = 'widget';
    await expectLater(
      LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: grant(),
        client: MockClient((_) async => http.Response(jsonEncode(json), 200)),
      ),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('uses the existing submission endpoint and exact JSON body', () async {
    final seen = <http.Request>[];
    final transport = await LuliVerifyNativeSessionTransport.connect(
      config: config,
      grant: grant(),
      client: MockClient((request) async {
        seen.add(request);
        return http.Response(jsonEncode(response(revision: seen.length)), 200);
      }),
    );
    addTearDown(transport.dispose);
    final body = {
      'revision': 1,
      'stepId': 'welcome',
      'idempotencyKey': 'native-test-001',
      'input': <String, Object?>{},
    };
    await transport.submit(body);
    expect(seen.last.method, 'POST');
    expect(
      seen.last.url.path,
      '/workflow-sessions/670100000000000000000003/steps',
    );
    expect(jsonDecode(seen.last.body), body);
  });
  test('disposal closes access and never emits another request', () async {
    var calls = 0;
    final transport = await LuliVerifyNativeSessionTransport.connect(
      config: config,
      grant: grant(),
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(response()), 200);
      }),
    );
    transport.dispose();
    await expectLater(transport.read(), throwsA(isA<LuliVerifyException>()));
    expect(calls, 1);
  });
}
