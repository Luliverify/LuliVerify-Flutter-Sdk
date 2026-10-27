import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/contracts/json_contract.dart';
import '../../core/network/native_session_transport.dart';
import '../../features/session/session_controller.dart';
import '../../features/session/workflow_session.dart';
import '../../platform/evidence_picker.dart';
import 'contract_form.dart';
import '../design/luli_components.dart';

/// The host owns/disposes controller and transport. Completion is advisory.
class LuliVerifySessionScreen extends StatefulWidget {
  const LuliVerifySessionScreen({
    super.key,
    required this.controller,
    required this.transport,
    this.onSessionEnded,
    this.onClose,
  });
  final LuliVerifySessionController controller;
  final LuliVerifyNativeSessionTransport transport;
  final ValueChanged<LuliVerifySession>? onSessionEnded;
  final VoidCallback? onClose;
  @override
  State<LuliVerifySessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<LuliVerifySessionScreen>
    with WidgetsBindingObserver {
  final _picker = LuliVerifyEvidencePicker();
  String? _stepId;
  String? _displayedStep;
  String? _slot;
  String? _documentType;
  final List<String> _assets = [];
  bool _consent = false;
  bool _uploading = false;
  String? _error;
  String? _notified;
  String? _attemptStamp;

  @override
  void initState() {
    super.initState();
    if (widget.controller.sessionId != widget.transport.sessionId) {
      throw ArgumentError(
        'Controller and transport must belong to the same session.',
      );
    }
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    if (widget.controller.phase == LuliVerifySessionPhase.idle) {
      widget.controller.refresh();
    }
  }

  @override
  void didUpdateWidget(covariant LuliVerifySessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.sessionId != widget.transport.sessionId) {
      throw ArgumentError(
        'Controller and transport must belong to the same session.',
      );
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _stepId = null;
      _displayedStep = null;
      _assets.clear();
      _notified = null;
      _error = null;
      if (widget.controller.phase == LuliVerifySessionPhase.idle) {
        widget.controller.refresh();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_uploading &&
        [
          LuliVerifySessionPhase.ready,
          LuliVerifySessionPhase.failed,
        ].contains(widget.controller.phase)) {
      widget.controller.refresh();
    }
  }

  void _changed() {
    final session = widget.controller.session;
    if (session?.isTerminal == true && _notified != session!.id) {
      _notified = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSessionEnded?.call(session);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Theme(
      data: LuliVerifyDesign.fromBranding(
        widget.controller.session?.raw['branding'] is Map
            ? jsonObject(widget.controller.session!.raw['branding'])
            : null,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: LuliVerifyDesign.ink,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            widget.controller.session?.raw['branding'] is Map
                ? (jsonObject(
                            widget.controller.session!.raw['branding'],
                          )['displayName']
                          as String? ??
                      'LuliVerify')
                : 'LuliVerify',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          actions: [
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Close verification',
                onPressed: _uploading ? null : widget.onClose,
                icon: const Icon(LucideIcons.x),
              ),
            IconButton(
              tooltip: 'Refresh session',
              onPressed:
                  _uploading ||
                      [
                        LuliVerifySessionPhase.loading,
                        LuliVerifySessionPhase.submitting,
                      ].contains(widget.controller.phase)
                  ? null
                  : () => widget.controller.refresh(),
              icon: const Icon(LucideIcons.refreshCw, size: 20),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;
              final session = controller.session;
              if (session == null && controller.requiresNewLaunch) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(controller.error!.message),
                        TextButton(
                          onPressed:
                              widget.onClose ??
                              () => Navigator.of(context).maybePop(),
                          child: const Text('Return to application'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (session == null) {
                return Center(
                  child: controller.error == null
                      ? const CircularProgressIndicator()
                      : TextButton(
                          onPressed: controller.refresh,
                          child: const Text('Retry connection'),
                        ),
                );
              }
              if (session.isTerminal ||
                  controller.phase == LuliVerifySessionPhase.expired) {
                final expired =
                    controller.phase == LuliVerifySessionPhase.expired;
                final completed = session.status.name == 'completed';
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Icon(
                        completed
                            ? LucideIcons.circleCheck
                            : expired
                            ? LucideIcons.clock
                            : LucideIcons.circleAlert,
                        size: 64,
                        color: LuliVerifyDesign.primary,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        expired
                            ? 'Session expired'
                            : completed
                            ? 'Verification submitted'
                            : session.status.name == 'cancelled'
                            ? 'Verification cancelled'
                            : 'Verification could not be completed',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        completed
                            ? 'Your verification steps are complete. The business will confirm the final outcome.'
                            : 'Return to the app to start again or get help.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: LuliVerifyDesign.muted,
                        ),
                      ),
                      if (session.testOnly)
                        const LuliNotice(
                          'Test session. This is not a production verification.',
                        ),
                      const Spacer(),
                      LuliButton(
                        label: 'Return to app',
                        onPressed:
                            widget.onClose ??
                            () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                );
              }
              final stepId =
                  _stepId != null && session.availableStepIds.contains(_stepId)
                  ? _stepId!
                  : session.currentStepId!;
              if (_displayedStep != stepId) {
                _stepId = stepId;
                _displayedStep = stepId;
                _assets.clear();
                _consent = false;
                _slot = null;
                _documentType = null;
              }
              final contract = session.contracts[stepId]!;
              final attempts = jsonList(session.raw['results'])
                  .map(jsonObject)
                  .where((result) => result['stepId'] == stepId)
                  .toList();
              final lastAttempt = attempts.lastOrNull;
              final stamp = lastAttempt == null
                  ? null
                  : '$stepId:${lastAttempt['attempt']}';
              if (_attemptStamp != stamp) {
                _attemptStamp = stamp;
                _assets.clear();
              }
              final branding = jsonObject(session.raw['branding']);
              final uploads = contract.uploads;
              final slots = jsonList(uploads['slots']).cast<String>();
              final types = jsonList(uploads['documentTypes']).cast<String>();
              if (slots.length == 1) _slot ??= slots.single;
              if (types.length == 1) _documentType ??= types.single;
              final progress = session.raw['toolProgress'] is List
                  ? jsonList(session.raw['toolProgress'])
                        .map(jsonObject)
                        .toList()
                  : <Map<String, Object?>>[];
              final finished = progress
                  .where((tool) => tool['status'] == 'completed')
                  .length;
              final face = session.raw['faceComparison'] is Map
                  ? jsonObject(session.raw['faceComparison'])
                  : null;
              final execution = jsonObject(contract.raw['execution']);
              final simulatedLiveness =
                  contract.toolType == 'liveness' && session.testOnly;
              final unsupported =
                  (contract.toolType == 'liveness' && !simulatedLiveness) ||
                  execution['otpDelivery'] == 'not_integrated';
              final scenario = jsonObject(contract.submission['scenario']);
              final developerRequired =
                  !simulatedLiveness &&
                  !['none', 'workflow'].contains(scenario['source']);
              final consentRequired =
                  contract.submission['consentRequired'] == true;
              final settings = jsonObject(session.raw['settings']);
              final steps = jsonList(session.raw['availableSubTools'])
                  .map(jsonObject)
                  .toList();
              final title =
                  steps.firstWhere((step) => step['id'] == stepId)['title']
                      as String? ??
                  contract.toolType;
              final description =
                  steps.firstWhere(
                        (step) => step['id'] == stepId,
                      )['description']
                      as String?;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (progress.isNotEmpty) ...[
                        Text(
                          '$finished of ${progress.length} steps complete',
                          style: const TextStyle(
                            fontSize: 14,
                            color: LuliVerifyDesign.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: finished / progress.length,
                            minHeight: 4,
                            backgroundColor: LuliVerifyDesign.surface,
                            color: LuliVerifyDesign.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      if (session.testOnly) const LuliNotice('Test session'),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                        ),
                      ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: LuliVerifyDesign.muted,
                            ),
                          ),
                        ),
                      if (simulatedLiveness)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              'Simulated liveness - test only. This does not verify that a real person is present.',
                            ),
                          ),
                        ),
                      if (lastAttempt != null &&
                          lastAttempt['outcome'] != 'passed')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(switch (lastAttempt['outcome']) {
                              'mismatch' => 'Details did not match. Check your information before retrying.',
                              'unavailable' => 'The verification service is unavailable. Try again later.',
                              _ => 'The check could not be completed. Review your information before retrying.',
                            }),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (steps.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: LuliSelect(
                            initialValue: stepId,
                            label: 'Verification option',
                            enabled: !_uploading && controller.canSubmit,
                            options: {
                              for (final step in steps)
                                step['id'] as String:
                                    step['title'] as String? ??
                                    step['type'] as String,
                            },
                            onChanged: _uploading
                                ? null
                                : (value) => setState(() => _stepId = value),
                          ),
                        ),
                      if (unsupported)
                        const Text(
                          'This step needs a verification provider that is not available in this SDK build. Contact the service administrator.',
                        ),
                      if (developerRequired)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            'This test workflow needs a developer-configured outcome before customers can continue.',
                          ),
                        ),
                      if (face != null)
                        LuliNotice(
                          face['ready'] == true
                              ? 'Your earlier document and passed liveness capture are ready for comparison.'
                              : 'Earlier evidence is missing, expired or not ready. Use the recovery action below to complete the required captures.',
                        ),
                      for (final requirement in jsonList(
                        contract.raw['evidenceRequirements'],
                      ))
                        LuliNotice(
                          jsonObject(requirement)['role'] == 'target'
                              ? 'Take a clear selfie. It will be used for face comparison after this step passes.'
                              : 'Provide a clear photo of your document. It will be reused for face comparison.',
                        ),
                      if (uploads['enabled'] == true &&
                          slots.isNotEmpty &&
                          !unsupported) ...[
                        if (slots.length > 1)
                          LuliSelect(
                            key: ValueKey('$stepId:slot'),
                            initialValue: _slot,
                            label: 'Document side',
                            enabled: !_uploading && controller.canSubmit,
                            options: {for (final slot in slots) slot: slot},
                            onChanged: _uploading
                                ? null
                                : (value) => setState(() => _slot = value),
                          ),
                        if (types.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: LuliSelect(
                              key: ValueKey('$stepId:type'),
                              initialValue: _documentType,
                              label: 'Document type',
                              enabled: !_uploading && controller.canSubmit,
                              options: {for (final type in types) type: type},
                              onChanged: _uploading
                                  ? null
                                  : (value) =>
                                        setState(() => _documentType = value),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            LuliButton(
                              secondary: true,
                              onPressed: _uploading || !controller.canSubmit
                                  ? null
                                  : () => _capture(false),
                              icon: LucideIcons.upload,
                              label: 'Choose file',
                            ),
                            LuliButton(
                              secondary: true,
                              onPressed: _uploading || !controller.canSubmit
                                  ? null
                                  : () => _capture(true),
                              icon: LucideIcons.camera,
                              label: 'Take photo',
                            ),
                          ],
                        ),
                        if (_uploading) const LinearProgressIndicator(),
                        if (_assets.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('${_assets.length} file(s) uploaded'),
                          ),
                        const SizedBox(height: 20),
                      ],
                      if (consentRequired)
                        Semantics(
                          checked: _consent,
                          enabled: !_uploading && controller.canSubmit,
                          child: InkWell(
                            onTap: _uploading || !controller.canSubmit
                                ? null
                                : () => setState(() => _consent = !_consent),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _consent
                                          ? LuliVerifyDesign.primary
                                          : Colors.white,
                                      border: Border.all(
                                        color: _consent
                                            ? LuliVerifyDesign.primary
                                            : LuliVerifyDesign.muted,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: _consent
                                        ? const Icon(
                                            LucideIcons.check,
                                            color: Colors.white,
                                            size: 18,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      settings['consentText'] as String? ??
                                          'Consent is required',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_error != null || controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ?? controller.error!.message,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (controller.phase == LuliVerifySessionPhase.failed)
                        TextButton(
                          onPressed: controller.requiresNewLaunch
                              ? () => Navigator.of(context).maybePop()
                              : controller.refresh,
                          child: Text(
                            controller.requiresNewLaunch
                                ? 'Return to application'
                                : 'Refresh session',
                          ),
                        ),
                      if (jsonObject(
                            session.raw['actions'],
                          )['canRecoverEvidence'] ==
                          true)
                        OutlinedButton(
                          onPressed: _uploading
                              ? null
                              : () => _evidenceOperation(() async {
                                  await widget.transport.recoverEvidence(
                                    session.revision,
                                  );
                                  _assets.clear();
                                }),
                          child: const Text('Recapture expired evidence'),
                        ),
                      for (var i = 0; i < _assets.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('File ${i + 1}'),
                          trailing: IconButton(
                            tooltip: 'Remove file',
                            icon: const Icon(LucideIcons.x, size: 20),
                            onPressed: _uploading
                                ? null
                                : () => _evidenceOperation(() async {
                                    final id = _assets[i];
                                    await widget.transport.removeFile(id);
                                    _assets.remove(id);
                                  }),
                          ),
                        ),
                      LuliVerifyContractForm(
                        key: ValueKey(stepId),
                        contract: contract,
                        continueLabel:
                            (contract.toolType == 'completion'
                                    ? branding['submitLabel']
                                    : branding['continueLabel'])
                                as String? ??
                            'Continue',
                        enabled:
                            controller.canSubmit &&
                            !_uploading &&
                            !unsupported &&
                            !developerRequired &&
                            (!consentRequired || _consent) &&
                            (uploads['required'] != true || _assets.isNotEmpty),
                        onSubmit: (input) async {
                          final bytes = List<int>.generate(
                            18,
                            (_) => Random.secure().nextInt(256),
                          );
                          final idempotencyKey = bytes
                              .map(
                                (byte) =>
                                    byte.toRadixString(16).padLeft(2, '0'),
                              )
                              .join();
                          await controller.submit(
                            stepId: stepId,
                            idempotencyKey: idempotencyKey,
                            simulateLiveness: simulatedLiveness,
                            input: {
                              ...input,
                              if (_assets.isNotEmpty)
                                'assetIds': List<String>.from(_assets),
                            },
                            consentAccepted: consentRequired ? _consent : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (branding['privacyUrl'] is String)
                            TextButton(
                              onPressed: () =>
                                  _openLink(branding['privacyUrl'] as String),
                              child: const Text('Privacy'),
                            ),
                          if (branding['termsUrl'] is String)
                            TextButton(
                              onPressed: () =>
                                  _openLink(branding['termsUrl'] as String),
                              child: const Text('Terms'),
                            ),
                          if (branding['supportUrl'] is String)
                            TextButton(
                              onPressed: () =>
                                  _openLink(branding['supportUrl'] as String),
                              child: Text(
                                branding['supportName'] as String? ?? 'Support',
                              ),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed:
                            _uploading ||
                                controller.phase != LuliVerifySessionPhase.ready
                            ? null
                            : controller.cancel,
                        child: const Text('Cancel verification'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Future<void> _capture(bool camera) async {
    final controller = widget.controller;
    final session = controller.session;
    if (session == null || _stepId == null || _slot == null) {
      setState(() => _error = 'Select the document side first.');
      return;
    }
    final contract = session.contracts[_stepId]!;
    if (contract.uploads['documentTypeRequired'] == true &&
        _documentType == null) {
      setState(() => _error = 'Select the document type first.');
      return;
    }
    if (_assets.length >= (contract.uploads['maxFiles'] as int)) {
      setState(() => _error = 'The maximum number of files has been reached.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final picked = await _picker.pick(
        contract: contract,
        camera: camera,
        testOnlyLiveness: session.testOnly && contract.toolType == 'liveness',
      );
      if (picked == null || !mounted) return;
      try {
        final id = await widget.transport.upload(
          contract: contract,
          slot: _slot!,
          bytes: picked.bytes,
          mimeType: picked.mimeType,
          documentType: _documentType,
        );
        if (mounted) setState(() => _assets.add(id));
      } finally {
        picked.bytes.fillRange(0, picked.bytes.length, 0);
      }
      if (mounted) await controller.refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to upload. Check permissions, file type and session, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _evidenceOperation(Future<void> Function() operation) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) await widget.controller.refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to update evidence. Refresh the session and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openLink(String value) async {
    try {
      final url = Uri.parse(value);
      if (url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const FormatException();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to open this link.');
    }
  }
}
