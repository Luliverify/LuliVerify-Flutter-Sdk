import '../../core/contracts/input_contract.dart';
import '../../core/contracts/json_contract.dart';
import '../../core/errors/luliverify_exception.dart';

/// LuliVerify session lifecycle state, distinct from local controller phases.
enum LuliVerifySessionStatus {
  /// Workflow remains in progress.
  active,

  /// LuliVerify session finished; this is not merchant authorization.
  completed,

  /// LuliVerify session ended unsuccessfully.
  failed,

  /// LuliVerify confirmed session cancellation.
  cancelled,

  /// LuliVerify marked the session expired.
  expired,
}

/// Deeply immutable, validated LuliVerify workflow/session snapshot.
///
/// Only current/available LuliVerify steps may be submitted. Public snapshots strip
/// the sessionToken but may still contain personal data; do not log the raw map.
final class LuliVerifySession {
  LuliVerifySession._(
    this.raw,
    this.id,
    this.revision,
    this.status,
    this.expiresAt,
    this.testOnly,
    this.contracts,
    this.currentStepId,
    this.availableStepIds,
  );

  /// Parses session data, without its API envelope.
  ///
  /// Validates status, expiry, contracts, current/available-step consistency and
  /// action flags. Throws LuliVerifyException for malformed or unsupported data.
  factory LuliVerifySession.fromJson(Object? json) {
    final decoded = jsonObject(json);
    final raw = jsonObject({...decoded}..remove('sessionToken'));
    final status = LuliVerifySessionStatus.values
        .where((status) => status.name == raw['status'])
        .firstOrNull;
    if (status == null) {
      throw const LuliVerifyException(
        'unsupported_status',
        'The SDK does not support this session state.',
      );
    }
    final expiryText = jsonString(raw['expiresAt']);
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(expiryText)) {
      invalidContract();
    }
    final expiry = DateTime.tryParse(expiryText);
    if (expiry == null) invalidContract();
    final contracts = jsonObject(raw['inputContracts']).map((key, value) {
      final contract = LuliVerifyInputContract.fromJson(value);
      if (contract.stepId != key) invalidContract();
      return MapEntry(key, contract);
    });
    String checkStep(Object? value) {
      final step = jsonObject(value);
      if (step['title'] is! String) invalidContract();
      final id = jsonString(step['id']);
      final contract = contracts[id];
      if (contract == null ||
          contract.toolType != step['type'] ||
          !sameJson(contract.raw, step['inputContract'])) {
        invalidContract();
      }
      return id;
    }

    final current = raw['currentStep'] == null
        ? null
        : checkStep(raw['currentStep']);
    final available = jsonList(raw['availableSubTools'])
        .map(checkStep)
        .toList();
    if (available.toSet().length != available.length) invalidContract();
    if (status == LuliVerifySessionStatus.active &&
        (current == null || !available.contains(current))) {
      invalidContract();
    }
    if (status != LuliVerifySessionStatus.active &&
        (current != null || available.isNotEmpty)) {
      invalidContract();
    }
    final actions = jsonObject(raw['actions']);
    final settings = jsonObject(raw['settings']);
    final branding = jsonObject(raw['branding']);
    for (final name in [
      'displayName',
      'continueLabel',
      'submitLabel',
      'supportName',
      'supportUrl',
      'privacyUrl',
      'termsUrl',
    ]) {
      if (branding[name] != null && branding[name] is! String) {
        invalidContract();
      }
    }
    jsonList(raw['results']).forEach(jsonObject);
    if (settings['consentText'] != null && settings['consentText'] is! String) {
      invalidContract();
    }
    for (final action in [
      'canSubmit',
      'canRecoverEvidence',
      'canResume',
      'canHandoff',
    ]) {
      jsonBool(actions[action]);
    }
    return LuliVerifySession._(
      raw,
      jsonString(raw['id']),
      jsonInteger(raw['revision']),
      status,
      expiry.toUtc(),
      jsonBool(raw['testOnly']),
      Map.unmodifiable(contracts),
      current,
      List.unmodifiable(available),
    );
  }

  /// Parses a successful statusCode-200 API envelope containing session data.
  ///
  /// Throws LuliVerifyException for a non-success or malformed envelope.
  factory LuliVerifySession.fromResponse(Object? json) {
    final envelope = jsonObject(json);
    if (envelope['statusCode'] != 200) invalidContract();
    return LuliVerifySession.fromJson(envelope['data']);
  }

  /// Complete immutable session data, excluding sessionToken.
  ///
  /// Evidence references, results or customer inputs may remain sensitive.
  final Map<String, Object?> raw;

  /// LuliVerify session identifier; this is not a bearer credential.
  final String id;

  /// LuliVerify revision required for the next optimistic-concurrency mutation.
  final int revision;

  /// Validated LuliVerify lifecycle state.
  final LuliVerifySessionStatus status;

  /// LuliVerify session expiry normalized to UTC.
  final DateTime expiresAt;

  /// Whether this session belongs to LuliVerify’s testing environment.
  final bool testOnly;

  /// Unmodifiable contracts indexed by their LuliVerify step IDs.
  final Map<String, LuliVerifyInputContract> contracts;

  /// Current step, or null for terminal snapshots.
  final String? currentStepId;

  /// Unmodifiable LuliVerify-authorized step choices for this snapshot.
  final List<String> availableStepIds;

  /// Whether the LuliVerify status is no longer active.
  bool get isTerminal => status != LuliVerifySessionStatus.active;

  /// LuliVerify action flag only; local busy/expiry checks still apply.
  bool get backendCanSubmit => jsonObject(raw['actions'])['canSubmit'] == true;
}
