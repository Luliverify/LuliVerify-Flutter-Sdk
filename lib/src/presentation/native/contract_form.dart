import 'package:flutter/material.dart';

import '../../core/contracts/input_contract.dart';
import '../../core/contracts/json_contract.dart';
import '../design/luli_components.dart';

/// Backend-driven scalar input form for advanced native presenters.
///
/// Supports text, email, date, finite numbers and selects. Evidence and consent
/// are managed by the surrounding session screen. Defaults/options/labels come
/// from the contract; the backend remains the final validation authority.
class LuliVerifyContractForm extends StatefulWidget {
  /// Creates a scalar form for [contract] and an awaited [onSubmit] handler.
  ///
  /// The handler must preserve backend field keys and surface session errors
  /// without logging personal input. [enabled] disables interaction;
  /// [continueLabel] supplies customer-facing action copy.
  const LuliVerifyContractForm({
    super.key,
    required this.contract,
    required this.onSubmit,
    this.enabled = true,
    this.continueLabel = 'Continue',
  });

  /// Current immutable contract; changing it clears locally collected values.
  final LuliVerifyInputContract contract;

  /// Receives validated scalar answers. Does not automatically attach evidence
  /// or consent; session orchestration must add those contract-required values.
  final Future<void> Function(Map<String, Object?>) onSubmit;

  /// Whether interaction/submission is permitted by the surrounding session flow.
  final bool enabled;

  /// Button copy, normally supplied by backend branding.
  final String continueLabel;
  @override
  State<LuliVerifyContractForm> createState() => _ContractFormState();
}

/// Owns transient scalar answers and client-side validation for one contract.
class _ContractFormState extends State<LuliVerifyContractForm> {
  final _form = GlobalKey<FormState>();
  final Map<String, Object?> _values = {};
  bool _busy = false;
  String? _error;

  /// Checks a scalar against supported backend metadata; returns local error copy.
  String? _validate(LuliVerifyInputField field, String? text) {
    final value = text ?? '';
    if (value.isEmpty) {
      return field.required ? '${field.label} is required.' : null;
    }
    final raw = field.raw;
    if (raw['minLength'] is int && value.length < (raw['minLength'] as int)) {
      return '${field.label} is too short.';
    }
    if (raw['maxLength'] is int && value.length > (raw['maxLength'] as int)) {
      return '${field.label} is too long.';
    }
    if (raw['pattern'] is String) {
      try {
        if (!RegExp(raw['pattern'] as String).hasMatch(value)) {
          return 'Enter a valid ${field.label}.';
        }
      } on FormatException {
        return 'This field requires an SDK update.';
      }
    }
    if (field.type == LuliVerifyFieldType.email &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    if (field.type == LuliVerifyFieldType.date) {
      final date = DateTime.tryParse(value);
      if (date == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          date.toIso8601String().substring(0, 10) != value) {
        return 'Enter a valid date (YYYY-MM-DD).';
      }
    }
    if (field.type == LuliVerifyFieldType.number) {
      final number = num.tryParse(value);
      if (number == null ||
          !number.isFinite ||
          (raw['minimum'] is num && number < (raw['minimum'] as num)) ||
          (raw['maximum'] is num && number > (raw['maximum'] as num))) {
        return 'Enter a valid ${field.label}.';
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant LuliVerifyContractForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameJson(oldWidget.contract.raw, widget.contract.raw)) {
      _values.clear();
      _error = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.contract.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: field.type == LuliVerifyFieldType.select
                  ? LuliSelect(
                      key: ValueKey('${widget.contract.stepId}:${field.key}'),
                      initialValue: field.raw['default'] as String?,
                      label: field.label,
                      enabled: enabled,
                      options: Map.fromEntries(
                        (field.raw['options'] as List).map((option) {
                          final item = option as Map;
                          return MapEntry(
                            item['value'] as String,
                            item['label'] as String,
                          );
                        }),
                      ),
                      onChanged: enabled
                          ? (value) => _values[field.key] = value
                          : null,
                      onSaved: (value) {
                        if (value != null) _values[field.key] = value;
                      },
                      validator: (value) => _validate(field, value),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.label,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey(
                            '${widget.contract.stepId}:${field.key}',
                          ),
                          enabled: enabled,
                          initialValue: field.raw['default'] as String?,
                          decoration: const InputDecoration(),
                          obscureText: field.raw['sensitive'] == true,
                          enableSuggestions: field.raw['sensitive'] != true,
                          autocorrect: false,
                          keyboardType: field.type == LuliVerifyFieldType.number
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                )
                              : field.type == LuliVerifyFieldType.email
                              ? TextInputType.emailAddress
                              : field.raw['inputMode'] == 'numeric'
                              ? TextInputType.number
                              : field.raw['inputMode'] == 'tel'
                              ? TextInputType.phone
                              : TextInputType.text,
                          onSaved: (value) {
                            if (value != null && value.isNotEmpty) {
                              _values[field.key] =
                                  field.type == LuliVerifyFieldType.number
                                  ? num.parse(value)
                                  : value;
                            }
                          },
                          validator: (value) => _validate(field, value),
                        ),
                      ],
                    ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          LuliButton(
            onPressed: !enabled
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    _values.clear();
                    _form.currentState!.save();
                    setState(() {
                      _busy = true;
                      _error = null;
                    });
                    try {
                      await widget.onSubmit(Map.unmodifiable(_values));
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error = 'Unable to continue. Check the session and try again.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            busy: _busy,
            label: _busy ? 'Submitting...' : widget.continueLabel,
          ),
        ],
      ),
    );
  }
}
