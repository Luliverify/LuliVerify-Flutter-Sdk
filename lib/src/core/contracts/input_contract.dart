import '../errors/luliverify_exception.dart';
import 'json_contract.dart';

enum LuliVerifyFieldType { text, email, date, number, select }

final class LuliVerifyInputField {
  LuliVerifyInputField._(
    this.raw,
    this.key,
    this.label,
    this.type,
    this.required,
  );

  factory LuliVerifyInputField.fromJson(Object? json) {
    final raw = jsonObject(json);
    final key = jsonString(raw['key']);
    for (final name in ['minLength', 'maxLength']) {
      if (raw[name] != null) jsonInteger(raw[name]);
    }
    for (final name in ['minimum', 'maximum']) {
      if (raw[name] != null &&
          (raw[name] is! num || !(raw[name] as num).isFinite)) {
        invalidContract();
      }
    }
    if (raw['default'] != null && raw['default'] is! String) invalidContract();
    if (raw['pattern'] != null && raw['pattern'] is! String) invalidContract();
    if (raw['sensitive'] != null) jsonBool(raw['sensitive']);
    final type = LuliVerifyFieldType.values
        .where((type) => type.name == raw['type'])
        .firstOrNull;
    if (type == null) {
      throw const LuliVerifyException(
        'unsupported_field',
        'This SDK does not support a field type required by this workflow.',
      );
    }
    if (type == LuliVerifyFieldType.select) {
      final options = jsonList(raw['options']);
      final seen = <String>{};
      if (options.isEmpty) invalidContract();
      for (final option in options) {
        final entry = jsonObject(option);
        if (!seen.add(jsonString(entry['value']))) invalidContract();
        jsonString(entry['label']);
      }
      if (raw['default'] != null && !seen.contains(raw['default'])) {
        invalidContract();
      }
    }
    return LuliVerifyInputField._(
      raw,
      key,
      jsonString(raw['label']),
      type,
      jsonBool(raw['required']),
    );
  }

  /// All backend validation/format/options metadata is retained without mutation.
  final Map<String, Object?> raw;
  final String key;
  final String label;
  final LuliVerifyFieldType type;
  final bool required;
}

final class LuliVerifyInputContract {
  LuliVerifyInputContract._(this.raw, this.stepId, this.toolType, this.fields);

  factory LuliVerifyInputContract.fromJson(Object? json) {
    final raw = jsonObject(json);
    if (raw['version'] != 1) {
      throw const LuliVerifyException(
        'unsupported_contract',
        'Update the SDK to use this workflow contract version.',
      );
    }
    if (![
      'strict',
      'legacy_configuration_only',
    ].contains(raw['validationMode'])) {
      invalidContract();
    }
    final fields = jsonList(raw['fields'])
        .map(LuliVerifyInputField.fromJson)
        .toList();
    final keys = fields.map((field) => field.key).toSet();
    if (keys.length != fields.length) invalidContract();
    final required = jsonList(raw['requiredFields']).map(jsonString).toSet();
    if (!sameJson(
      required.toList()..sort(),
      fields.where((field) => field.required).map((field) => field.key).toList()
        ..sort(),
    )) {
      invalidContract();
    }
    final submission = jsonObject(raw['submission']);
    final stepId = jsonString(raw['stepId']);
    if (submission['stepId'] != stepId ||
        submission['method'] != 'POST' ||
        submission['inputField'] != 'input' ||
        submission['path'] != '/workflow-sessions/:id/steps') {
      invalidContract();
    }
    final envelope = jsonList(submission['requiredEnvelopeFields'])
        .map(jsonString)
        .toSet();
    const supportedEnvelope = {
      'revision',
      'stepId',
      'idempotencyKey',
      'input',
      'consentAccepted',
    };
    if (!supportedEnvelope.containsAll(envelope) ||
        !envelope.containsAll({
          'revision',
          'stepId',
          'idempotencyKey',
          'input',
        })) {
      throw const LuliVerifyException(
        'unsupported_contract',
        'Update the SDK to use this submission contract.',
      );
    }
    jsonInteger(submission['inputMaxProperties']);
    jsonBool(submission['consentRequired']);
    jsonObject(submission['scenario']);
    final uploads = jsonObject(raw['uploads']);
    jsonBool(uploads['enabled']);
    jsonBool(uploads['required']);
    jsonList(uploads['slots']).forEach(jsonString);
    jsonList(uploads['mimeTypes']).forEach(jsonString);
    jsonList(uploads['documentTypes']).forEach(jsonString);
    jsonInteger(uploads['maxBytes']);
    jsonInteger(uploads['maxFiles']);
    return LuliVerifyInputContract._(
      raw,
      stepId,
      jsonString(raw['toolType']),
      List.unmodifiable(fields),
    );
  }

  /// Complete backend evidence, upload, submission and configuration metadata.
  final Map<String, Object?> raw;
  final String stepId;
  final String toolType;
  final List<LuliVerifyInputField> fields;
  Map<String, Object?> get submission => jsonObject(raw['submission']);
  Map<String, Object?> get uploads => jsonObject(raw['uploads']);
}
