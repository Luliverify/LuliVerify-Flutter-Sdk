import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/contracts/json_contract.dart';
import '../../core/errors/luliverify_exception.dart';
import '../../core/network/session_transport.dart';
import 'workflow_session.dart';

/// Local orchestration phase, distinct from the backend session status.
enum LuliVerifySessionPhase {
  /// No session read has started.
  idle,

  /// A session read is in progress.
  loading,

  /// A snapshot is available; backend action flags still govern submission.
  ready,

  /// A step mutation or cancellation is in progress.
  submitting,

  /// An operation could not be confirmed; inspect the sanitized error.
  failed,

  /// The active session has reached its expiry boundary.
  expired,

  /// A completed, failed, cancelled or expired backend state was adopted.
  terminal,

  /// Local controller resources have been released.
  disposed,
}

/// Observable, revision-safe owner of one session transport.
///
/// Subscribe with ChangeNotifier listeners or a ListenableBuilder. Operations are
/// serialized, stale snapshots are rejected, and disposing closes the transport.
/// Notifications and terminal states are advisory, never approval.
final class LuliVerifySessionController extends ChangeNotifier {
  /// Creates a controller bound to [sessionId] and an owned transport.
  ///
  /// The transport must address that same session. The optional clock supplies
  /// local expiry time for deterministic tests; production defaults to DateTime.now.
  /// Call [refresh] before submission and [dispose] when the flow ends.
  LuliVerifySessionController({
    required this.sessionId,
    required this._transport,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Session identifier every adopted transport response must match.
  final String sessionId;
  final LuliVerifySessionTransport _transport;
  final DateTime Function() _clock;
  LuliVerifySession? _session;
  LuliVerifySessionPhase _phase = LuliVerifySessionPhase.idle;
  LuliVerifyException? _error;
  bool _busy = false;
  bool _disposed = false;
  int _notificationDepth = 0;
  bool _notifierDisposePending = false;
  Timer? _expiry;

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_notificationDepth == 0 && _notifierDisposePending) {
        _notifierDisposePending = false;
        super.dispose();
      }
    }
  }

  /// Latest accepted immutable snapshot, or null before load/after access ends.
  LuliVerifySession? get session => _session;

  /// Sanitized last operation failure; provider payloads are not propagated.
  LuliVerifyException? get error => _error;

  /// Whether access failure requires new authorized session credentials.
  ///
  /// Refresh alone cannot repair unauthorized, forbidden, or expired-grant access.
  bool get requiresNewLaunch =>
      ['unauthorized', 'forbidden', 'grant_expired'].contains(_error?.code);

  /// Current local phase, including expiry computed from the injected clock.
  LuliVerifySessionPhase get phase =>
      !_disposed &&
          _session?.isTerminal == false &&
          !_session!.expiresAt.isAfter(_clock())
      ? LuliVerifySessionPhase.expired
      : _phase;

  /// True only when ready, not busy and explicitly allowed by backend action flags.
  bool get canSubmit =>
      phase == LuliVerifySessionPhase.ready &&
      !_busy &&
      _session?.backendCanSubmit == true;

  /// Fetches and adopts the latest snapshot without advancing a step.
  ///
  /// Guard failures throw LuliVerifyException. Transport/contract failures are
  /// stored in [error] with [phase] failed; the Future may complete normally.
  /// Inspect controller state before continuing and do not overlap operations.
  Future<void> refresh() => _run(() => _transport.read(), false);

  /// Submits answers for an available step at the current backend revision.
  ///
  /// [stepId] must be currently available. [idempotencyKey] is an 8–100 character
  /// letters/digits/underscore/hyphen request identifier; do not blindly replay an
  /// uncertain mutation. [input] uses backend keys/values, not display labels.
  /// [consentAccepted] must be true when the contract requires consent.
  ///
  /// [simulateLiveness] is permitted only for backend-marked test liveness and
  /// preserves workflow-authored outcomes; it cannot enable production liveness.
  /// Validation/overlap guards throw LuliVerifyException. I/O failures are captured
  /// in [error]; inspect [phase] after awaiting and refresh before retrying.
  Future<void> submit({
    required String stepId,
    required String idempotencyKey,
    required Map<String, Object?> input,
    bool? consentAccepted,
    bool simulateLiveness = false,
  }) async {
    if (!canSubmit) {
      throw const LuliVerifyException(
        'not_ready',
        'Refresh or recover the session before submitting.',
      );
    }
    final current = _session!;
    if (!current.availableStepIds.contains(stepId)) {
      throw const LuliVerifyException(
        'unavailable_step',
        'This step is not available.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{8,100}$').hasMatch(idempotencyKey)) {
      throw const LuliVerifyException(
        'invalid_idempotency_key',
        'A valid idempotency key is required.',
      );
    }
    final contract = current.contracts[stepId]!;
    final policy = contract.submission;
    final scenario = jsonObject(policy['scenario']);
    if (simulateLiveness &&
        (!current.testOnly || contract.toolType != 'liveness')) {
      throw const LuliVerifyException(
        'simulation_forbidden',
        'Liveness simulation is available only for test liveness steps.',
      );
    }
    if (!simulateLiveness &&
        !['none', 'workflow'].contains(scenario['source'])) {
      throw const LuliVerifyException(
        'test_runner_required',
        'This step requires developer test input; customers must not select test outcomes.',
      );
    }
    if (policy['consentRequired'] == true && consentAccepted != true) {
      throw const LuliVerifyException(
        'consent_required',
        'Consent is required before continuing.',
      );
    }
    if (input.length > (policy['inputMaxProperties'] as int)) {
      throw const LuliVerifyException(
        'invalid_input',
        'Too many input properties.',
      );
    }
    final body = jsonObject({
      'revision': current.revision,
      'stepId': stepId,
      'idempotencyKey': idempotencyKey,
      'input': input,
      if (simulateLiveness && scenario['source'] != 'workflow')
        'scenario': 'success',
      'consentAccepted': ?consentAccepted,
    });
    await _run(() => _transport.submit(body), true);
  }

  /// Requests remote cancellation when a non-terminal session is ready.
  ///
  /// Throws LuliVerifyException if disposed, busy, not ready or terminal. Network
  /// failures are stored in [error]; only a cancelled snapshot confirms cancellation.
  Future<void> cancel() async {
    if (_disposed ||
        _busy ||
        _session == null ||
        _session!.isTerminal ||
        phase != LuliVerifySessionPhase.ready) {
      throw const LuliVerifyException(
        'not_ready',
        'The session cannot be cancelled now.',
      );
    }
    await _run(() => _transport.cancel(), true);
  }

  /// Serializes I/O, sanitizes failures and adopts only forward-compatible revisions.
  Future<void> _run(
    Future<LuliVerifySession> Function() operation,
    bool mutation,
  ) async {
    if (_disposed || _busy) {
      throw const LuliVerifyException(
        'operation_in_progress',
        'The session is closed or another operation is running.',
      );
    }
    _busy = true;
    _error = null;
    _phase = mutation
        ? LuliVerifySessionPhase.submitting
        : LuliVerifySessionPhase.loading;
    notifyListeners();
    try {
      if (_disposed) return;
      final next = await operation();
      if (_disposed) return;
      if (next.id != sessionId ||
          (_session != null &&
              (next.revision < _session!.revision ||
                  (mutation && next.revision <= _session!.revision))) ||
          (_session?.isTerminal == true && !next.isTerminal)) {
        throw const LuliVerifyException(
          'stale_session',
          'Refresh the session before continuing.',
        );
      }
      _session = next;
      _phase = next.isTerminal
          ? LuliVerifySessionPhase.terminal
          : LuliVerifySessionPhase.ready;
      _expiry?.cancel();
      if (!next.isTerminal) {
        final delay = next.expiresAt.difference(_clock());
        if (delay > Duration.zero) {
          _expiry = Timer(delay, () {
            if (!_disposed) notifyListeners();
          });
        }
      }
    } catch (error) {
      if (_disposed) return;
      // Transport/provider errors may contain personal data. Do not propagate them.
      final code =
          error is LuliVerifyException &&
              [
                'unauthorized',
                'forbidden',
                'rate_limited',
                'unsupported_contract',
                'unsupported_field',
                'unsupported_status',
              ].contains(error.code)
          ? error.code
          : 'refresh_required';
      _error = LuliVerifyException(
        code,
        ['unauthorized', 'forbidden'].contains(code)
            ? 'Session access ended. Return to your application for a new launch.'
            : code.startsWith('unsupported_')
            ? 'This workflow requires an SDK update.'
            : code == 'rate_limited'
            ? 'Too many requests. Wait before trying again.'
            : 'The request could not be confirmed. Refresh before trying again.',
      );
      _phase = LuliVerifySessionPhase.failed;
      if (requiresNewLaunch) {
        _session = null;
        _expiry?.cancel();
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  /// Closes the owned transport, cancels expiry notifications and clears snapshots.
  ///
  /// Idempotent locally; late responses are ignored. Does not request remote
  /// cancellation. Explicitly call [cancel] first if remote cancellation is needed.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _phase = LuliVerifySessionPhase.disposed;
    _expiry?.cancel();
    _session = null;
    _error = null;
    try {
      _transport.dispose();
    } finally {
      if (_notificationDepth > 0) {
        _notifierDisposePending = true;
      } else {
        super.dispose();
      }
    }
  }
}
