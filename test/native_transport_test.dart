import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  test(
    'multipart progress reports streamed bytes and preserves abort support',
    () async {
      final json = jsonDecode(
        File('test/fixtures/liveness_session.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      json['data']['sessionToken'] = 't' * 43;
      final progress = <(int, int)>[];
      final transport = await LuliVerifyNativeSessionTransport.connect(
        config: config,
        grant: grant(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/files')) {
            expect(progress, isNotEmpty);
            expect(progress.last.$1, progress.last.$2);
            expect(request.bodyBytes.length, progress.last.$2);
            return http.Response(
              jsonEncode({
                'statusCode': 200,
                'data': {'id': '670100000000000000000099'},
              }),
              200,
            );
          }
          return http.Response(jsonEncode(json), 200);
        }),
      );
      addTearDown(transport.dispose);
      final contract = transport.initialSession.contracts.values.firstWhere(
        (c) => c.toolType == 'liveness',
      );
      await transport.upload(
        contract: contract,
        slot: 'selfie',
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0]),
        mimeType: 'image/jpeg',
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
        expect(progress[i].$2, progress.first.$2);
      }
    },
  );
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
