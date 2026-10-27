import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

LuliVerifySession snapshot({
  int revision = 0,
  String status = 'active',
  String? id,
  bool canSubmit = true,
}) {
  final json = jsonDecode(
    File('test/fixtures/business_session.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final data = json['data'] as Map<String, dynamic>;
  data['revision'] = revision;
  data['status'] = status;
  if (id != null) data['id'] = id;
  data['actions']['canSubmit'] = canSubmit;
  if (status != 'active') {
    data['currentStep'] = null;
    data['availableSubTools'] = [];
  }
  return LuliVerifySession.fromResponse(json);
}

class FakeTransport implements LuliVerifySessionTransport {
  Future<LuliVerifySession> Function() onRead = () async => snapshot();
  Future<LuliVerifySession> Function() onSubmit = () async =>
      snapshot(revision: 1);
  Map<String, Object?>? submitted;
  bool disposed = false;
  int calls = 0;
  @override
  Future<LuliVerifySession> read() => onRead();
  @override
  Future<LuliVerifySession> submit(Map<String, Object?> body) {
    calls++;
    submitted = body;
    return onSubmit();
  }

  @override
  Future<LuliVerifySession> cancel() async =>
      snapshot(revision: 1, status: 'cancelled');
  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  for (final testOnly in [true, false]) {
    test(
      'dummy liveness is ${testOnly ? 'allowed for test' : 'blocked for production'} sessions',
      () async {
        final json = jsonDecode(
          File('test/fixtures/liveness_session.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        json['data']['testOnly'] = testOnly;
        final transport = FakeTransport()
          ..onRead = () async => LuliVerifySession.fromResponse(json);
        final controller = LuliVerifySessionController(
          sessionId: '670100000000000000000003',
          transport: transport,
        );
        addTearDown(controller.dispose);
        await controller.refresh();
        final request = controller.submit(
          stepId: controller.session!.currentStepId!,
          idempotencyKey: 'test-liveness-001',
          input: {
            'assetIds': ['670100000000000000000006'],
          },
          simulateLiveness: true,
        );
        if (testOnly) {
          await request;
          expect(transport.submitted!['scenario'], 'success');
        } else {
          await expectLater(
            request,
            throwsA(
              isA<LuliVerifyException>().having(
                (e) => e.code,
                'code',
                'simulation_forbidden',
              ),
            ),
          );
          expect(transport.calls, 0);
        }
      },
    );
  }
  late FakeTransport transport;
  late LuliVerifySessionController controller;
  setUp(() {
    transport = FakeTransport();
    controller = LuliVerifySessionController(
      sessionId: snapshot().id,
      transport: transport,
    );
  });
  tearDown(() => controller.dispose());

  Future<void> submit() => controller.submit(
    stepId: snapshot().currentStepId!,
    idempotencyKey: 'attempt_0001',
    input: {},
  );

  test('loads authoritative state and sends exact revision/envelope', () async {
    await controller.refresh();
    await submit();
    expect(transport.submitted, {
      'revision': 0,
      'stepId': snapshot().currentStepId,
      'idempotencyKey': 'attempt_0001',
      'input': {},
    });
    expect(controller.session!.revision, 1);
  });
  test('rejects submissions before initial load', () async {
    await expectLater(submit(), throwsA(isA<LuliVerifyException>()));
    expect(transport.calls, 0);
  });
  test('serializes mutations and never retries automatically', () async {
    await controller.refresh();
    final pending = Completer<LuliVerifySession>();
    transport.onSubmit = () => pending.future;
    final first = submit();
    await expectLater(submit(), throwsA(isA<LuliVerifyException>()));
    pending.complete(snapshot(revision: 1));
    await first;
    expect(transport.calls, 1);
  });
  test(
    'unknown mutation outcomes require a refresh and redact transport errors',
    () async {
      await controller.refresh();
      transport.onSubmit = () async => throw Exception('synthetic-secret');
      await submit();
      expect(controller.phase, LuliVerifySessionPhase.failed);
      expect(controller.error.toString(), isNot(contains('synthetic-secret')));
      await expectLater(submit(), throwsA(isA<LuliVerifyException>()));
      await controller.refresh();
      expect(controller.canSubmit, true);
    },
  );
  test('rejects stale revisions and wrong session IDs', () async {
    transport.onRead = () async => snapshot(revision: 4);
    await controller.refresh();
    transport.onRead = () async => snapshot(revision: 3);
    await controller.refresh();
    expect(controller.phase, LuliVerifySessionPhase.failed);
    expect(controller.session!.revision, 4);
    transport.onRead = () async => snapshot(id: 'another-session', revision: 5);
    await controller.refresh();
    expect(controller.session!.id, snapshot().id);
  });
  test('does not allow mutation when backend disables submission', () async {
    transport.onRead = () async => snapshot(canSubmit: false);
    await controller.refresh();
    await expectLater(submit(), throwsA(isA<LuliVerifyException>()));
  });
  test('cancellation adopts backend terminal status', () async {
    await controller.refresh();
    await controller.cancel();
    expect(controller.session!.status, LuliVerifySessionStatus.cancelled);
    expect(controller.canSubmit, false);
  });
  test('disposal ignores late responses and releases transport', () async {
    final pending = Completer<LuliVerifySession>();
    transport.onRead = () => pending.future;
    final read = controller.refresh();
    controller.dispose();
    pending.complete(snapshot());
    await read;
    expect(controller.session, null);
    expect(transport.disposed, true);
    expect(controller.phase, LuliVerifySessionPhase.disposed);
  });
  test('expired sessions cannot submit', () async {
    controller.dispose();
    controller = LuliVerifySessionController(
      sessionId: snapshot().id,
      transport: transport,
      clock: () => DateTime.utc(2100),
    );
    await controller.refresh();
    expect(controller.phase, LuliVerifySessionPhase.expired);
    await expectLater(submit(), throwsA(isA<LuliVerifyException>()));
  });
  test('unchanged mutation revisions require refresh', () async {
    await controller.refresh();
    transport.onSubmit = () async => snapshot();
    await submit();
    expect(controller.canSubmit, false);
    expect(controller.phase, LuliVerifySessionPhase.failed);
  });
  test(
    'disposal from a notification prevents the request from starting',
    () async {
      var reads = 0;
      transport.onRead = () async {
        reads++;
        return snapshot();
      };
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        controller.addListener(controller.dispose);
        await controller.refresh();
      } finally {
        FlutterError.onError = previous;
      }
      expect(reads, 0);
      expect(errors, isEmpty);
    },
  );
  test(
    'does not expose developer outcome selection to customer flows',
    () async {
      final json = jsonDecode(
        File('test/fixtures/business_session.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final entry = (data['inputContracts'] as Map).entries.firstWhere(
        (dynamic item) => item.value['toolType'] == 'cac',
      );
      final step = {
        'id': entry.key,
        'type': 'cac',
        'title': 'Company lookup',
        'inputContract': entry.value,
      };
      data['currentStep'] = step;
      data['availableSubTools'] = [step];
      transport.onRead = () async => LuliVerifySession.fromResponse(json);
      await controller.refresh();
      await expectLater(
        controller.submit(
          stepId: entry.key as String,
          idempotencyKey: 'attempt_0001',
          input: {},
        ),
        throwsA(
          isA<LuliVerifyException>().having(
            (e) => e.code,
            'code',
            'test_runner_required',
          ),
        ),
      );
      expect(transport.calls, 0);
    },
  );
}
