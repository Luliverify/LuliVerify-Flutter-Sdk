import '../../core/contracts/input_contract.dart';
import '../../core/contracts/json_contract.dart';
import '../../core/errors/luliverify_exception.dart';

enum LuliVerifySessionStatus { active, completed, failed, cancelled, expired }

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

  factory LuliVerifySession.fromResponse(Object? json) {
    final envelope = jsonObject(json);
    if (envelope['statusCode'] != 200) invalidContract();
    return LuliVerifySession.fromJson(envelope['data']);
  }

  /// The session token is deliberately excluded from the public snapshot.
  final Map<String, Object?> raw;
  final String id;
  final int revision;
  final LuliVerifySessionStatus status;
  final DateTime expiresAt;
  final bool testOnly;
  final Map<String, LuliVerifyInputContract> contracts;
  final String? currentStepId;
  final List<String> availableStepIds;
  bool get isTerminal => status != LuliVerifySessionStatus.active;
  bool get backendCanSubmit => jsonObject(raw['actions'])['canSubmit'] == true;
}
