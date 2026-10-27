import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/fixtures/business_session.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test(
    'rejects new required submission fields instead of silently omitting them',
    () {
      final json = fixture();
      final contract = (json['data']['inputContracts'] as Map).values.first;
      contract['submission']['requiredEnvelopeFields'].add('newRequiredValue');
      expect(
        () => LuliVerifySession.fromResponse(json),
        throwsA(
          isA<LuliVerifyException>().having(
            (e) => e.code,
            'code',
            'unsupported_contract',
          ),
        ),
      );
    },
  );
  test('rejects malformed revisions and timestamps', () {
    final json = fixture();
    json['data']['revision'] = -1;
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(isA<LuliVerifyException>()),
    );
    final next = fixture();
    next['data']['expiresAt'] = '2099-01-01';
    expect(
      () => LuliVerifySession.fromResponse(next),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('parses the actual backend contract and preserves field options', () {
    final session = LuliVerifySession.fromResponse(fixture());
    final cac = session.contracts.values.firstWhere(
      (item) => item.toolType == 'cac',
    );
    expect(
      cac.fields.map((field) => field.key),
      containsAll(['registrationNumber', 'companyName', 'detailLevel']),
    );
    expect(
      cac.fields
          .firstWhere((field) => field.key == 'detailLevel')
          .raw['default'],
      'basic',
    );
    expect(cac.uploads['enabled'], false);
    expect(session.testOnly, true);
  });
  test('contracts are deeply immutable', () {
    final session = LuliVerifySession.fromResponse(fixture());
    expect(() => session.raw['revision'] = 2, throwsUnsupportedError);
    expect(() => session.contracts.clear(), throwsUnsupportedError);
    expect(
      () => session.contracts.values.first.raw.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (session.raw['results'] as List).add({}),
      throwsUnsupportedError,
    );
  });
  test('does not retain exchange tokens in public snapshots', () {
    final json = fixture();
    json['data']['sessionToken'] = 'synthetic-secret';
    expect(
      LuliVerifySession.fromResponse(json).raw.containsKey('sessionToken'),
      false,
    );
  });
  test('rejects unsupported contract versions', () {
    final json = fixture();
    (json['data']['inputContracts'] as Map).values.first['version'] = 2;
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(
        isA<LuliVerifyException>().having(
          (e) => e.code,
          'code',
          'unsupported_contract',
        ),
      ),
    );
  });
  test('rejects unknown field types without leaking payload values', () {
    final json = fixture();
    final contract = (json['data']['inputContracts'] as Map).values.firstWhere(
      (dynamic item) => item['toolType'] == 'cac',
    );
    contract['fields'][0]['type'] = 'secret-value';
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(
        isA<LuliVerifyException>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('secret-value')),
        ),
      ),
    );
  });
  test('rejects inconsistent current step and registry', () {
    final json = fixture();
    json['data']['currentStep']['inputContract']['toolType'] = 'unknown';
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('rejects non-boolean action flags', () {
    final json = fixture();
    json['data']['actions']['canSubmit'] = 'true';
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('rejects active sessions without a usable current step', () {
    final json = fixture();
    json['data']['availableSubTools'] = [];
    expect(
      () => LuliVerifySession.fromResponse(json),
      throwsA(isA<LuliVerifyException>()),
    );
  });
  test('accepts terminal snapshots without a current step', () {
    final json = fixture();
    json['data']['status'] = 'completed';
    json['data']['currentStep'] = null;
    json['data']['availableSubTools'] = [];
    expect(LuliVerifySession.fromResponse(json).isTerminal, true);
  });
}
