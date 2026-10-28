import 'dart:async';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:http/http.dart' as http;

import 'core/config/luliverify_config.dart';
import 'core/errors/luliverify_exception.dart';
import 'core/network/native_session_transport.dart';
import 'features/session/session_controller.dart';
import 'presentation/design/luli_components.dart';
import 'presentation/design/session_states.dart';
import 'presentation/hosted/hosted_launch.dart';
import 'presentation/native/session_screen.dart';

/// Reason an SDK-owned verification route returned to its caller.
///
/// Native session statuses and hosted navigation statuses are distinct. None is
/// merchant-authoritative approval; use trusted backend results for decisions.
enum LuliVerifyResultStatus {
  /// The native backend session completed; this is not an authorization decision.
  completed,

  /// The native backend session ended with a failed status.
  failed,

  /// Cancellation of the native backend session was confirmed.
  cancelled,

  /// The native session expired according to the backend or local expiry clock.
  expired,

  /// The local route closed without confirmed remote cancellation/completion.
  ///
  /// In hosted mode this does not cancel the browser session.
  dismissed,

  /// A matching hosted return link arrived while the SDK route was alive.
  ///
  /// This reports navigation only and does not imply verification passed.
  hostedReturned,

  /// The route closed after a sanitized SDK error; inspect the result errorCode.
  error,
}

/// Advisory result returned when the SDK route closes.
///
/// A session may not have been created, so [sessionId], [testOnly] and
/// [errorCode] can be null. Never use this object alone to grant account access.
final class LuliVerifyResult {
  /// Creates an immutable session/navigation result.
  ///
  /// Use [status] to distinguish confirmed native states from hosted return or
  /// local dismissal. The constructor itself does not validate a backend outcome.
  const LuliVerifyResult({
    required this.status,
    this.sessionId,
    this.testOnly,
    this.errorCode,
  });

  /// Reason the SDK returned control to the host application.
  final LuliVerifyResultStatus status;

  /// Backend session identifier, or null if no session was obtained.
  ///
  /// An identifier is not a credential and cannot restore session access.
  final String? sessionId;

  /// Backend test-mode flag, or null when launch metadata was unavailable.
  ///
  /// Customer-facing screens omit test notices; this flag is still retained.
  final bool? testOnly;

  /// Sanitized SDK error category when available; excludes provider payloads.
  final String? errorCode;
}

/// Primary entry point for native and hosted workflow verification.
///
/// Prefer [launch] over composing transports/controllers manually. The SDK owns
/// its route and resources; only one launch may be open in this Dart isolate.
abstract final class LuliVerify {
  static bool _launching = false;

  /// Opens a published workflow and resolves when its SDK route closes.
  ///
  /// [context] must be mounted below a Navigator. The root Navigator receives an
  /// SDK-owned route and theme; no host-authored SDK screen is required.
  ///
  /// [publishableKey] must be an issued creation-only key that permits [releaseId],
  /// the published release ID (not a workflow/draft ID). Changes require publishing
  /// and supplying the replacement release. [customerReference] is optional,
  /// 1–150 characters when provided, and is correlation rather than authentication.
  ///
  /// [mode] defaults to native UI. Hosted mode opens the external browser and
  /// requires [returnUrl]: an exact backend-registered HTTPS App/Universal Link.
  /// The host must configure OS/domain associations. Native mode must omit it.
  /// A matching link resolves as [LuliVerifyResultStatus.hostedReturned], not
  /// completed. Cold-start restoration after process death is not implemented.
  ///
  /// [apiBaseUrl] defaults to https://luli-api.luliverify.io. [widgetOrigin] defaults
  /// to https://verify.luliverify.io and validates hosted launch origin.
  /// [httpClientFactory] is an advanced/testing hook: return a new client each time;
  /// the SDK owns and closes every supplied client. Never add private credentials,
  /// browser Origin headers, cookies or automatic mutation retries.
  ///
  /// Throws [StateError] for a concurrent launch and [ArgumentError] for invalid
  /// API configuration. A missing Navigator also throws before a flow opens.
  /// Failures inside the opened route are presented there and normally become a
  /// sanitized error result on close. Await the result and check context.mounted
  /// before updating host UI. Callbacks never authorize a customer.
  static Future<LuliVerifyResult> launch(
    BuildContext context, {
    required String publishableKey,
    required String releaseId,
    LuliVerifyPresentation mode = LuliVerifyPresentation.nativeUi,
    Uri? apiBaseUrl,
    String? customerReference,
    Uri? returnUrl,
    Uri? widgetOrigin,
    http.Client Function()? httpClientFactory,
  }) async {
    if (_launching) throw StateError('A LuliVerify flow is already open.');
    final config = LuliVerifyConfig(
      apiBaseUrl: apiBaseUrl ?? Uri.parse('https://luli-api.luliverify.io'),
      presentation: mode,
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    _launching = true;
    try {
      return await navigator.push<LuliVerifyResult>(
            PageRouteBuilder(
              settings: const RouteSettings(name: 'luliverify'),
              transitionDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  Localizations.override(
                    context: context,
                    locale: const Locale('en'),
                    delegates: const [DefaultMaterialLocalizations.delegate],
                    child: Theme(
                      data: LuliVerifyDesign.theme(),
                      child: _LaunchScreen(
                        config: config,
                        publishableKey: publishableKey,
                        releaseId: releaseId,
                        customerReference: customerReference,
                        returnUrl: returnUrl,
                        httpClientFactory: httpClientFactory,
                        widgetOrigin:
                            widgetOrigin ??
                            Uri.parse('https://verify.luliverify.io'),
                      ),
                    ),
                  ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
            ),
          ) ??
          const LuliVerifyResult(status: LuliVerifyResultStatus.dismissed);
    } finally {
      _launching = false;
    }
  }
}

/// Owns the routed native/hosted launch boundary and its public configuration.
class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen({
    required this.config,
    required this.publishableKey,
    required this.releaseId,
    required this.widgetOrigin,
    this.customerReference,
    this.returnUrl,
    this.httpClientFactory,
  });
  final LuliVerifyConfig config;
  final String publishableKey, releaseId;
  final String? customerReference;
  final Uri? returnUrl;
  final Uri widgetOrigin;
  final http.Client Function()? httpClientFactory;
  @override
  State<_LaunchScreen> createState() => _LaunchState();
}

/// Maintains memory-only launch/session resources until the SDK route closes.
class _LaunchState extends State<_LaunchScreen> {
  http.Client? _pendingClient;
  LuliVerifyNativeSessionTransport? _transport;
  LuliVerifySessionController? _controller;
  StreamSubscription<Uri>? _links;
  LuliVerifyHostedLaunch? _hosted;
  String? _sessionId, _errorCode;
  bool? _testOnly;
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Creates one launch, then exchanges native access or installs hosted link listening.
  ///
  /// No automatic retry is safe after an ambiguous one-use ticket exchange.
  Future<void> _start() async {
    try {
      _pendingClient = widget.httpClientFactory?.call() ?? http.Client();
      final nonce = List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final data = await LuliVerifyNativeSessionTransport.createLaunch(
        config: widget.config,
        publishableKey: widget.publishableKey,
        releaseId: widget.releaseId,
        idempotencyKey: nonce,
        customerReference: widget.customerReference,
        returnUrl: widget.returnUrl,
        client: _pendingClient,
      );
      _pendingClient = null;
      if (!mounted) return;
      _sessionId = data['sessionId'] as String;
      _testOnly = data['testOnly'] as bool;
      if (widget.config.presentation == LuliVerifyPresentation.nativeUi) {
        _pendingClient = widget.httpClientFactory?.call() ?? http.Client();
        final transport = await LuliVerifyNativeSessionTransport.connect(
          config: widget.config,
          grant: LuliVerifyNativeGrant.fromJson(data),
          client: _pendingClient,
        );
        _pendingClient = null;
        if (!mounted) {
          transport.dispose();
          return;
        }
        _transport = transport;
        _controller = LuliVerifySessionController(
          sessionId: transport.sessionId,
          transport: transport,
        );
        await _controller!.refresh();
      } else {
        _hosted = LuliVerifyHostedLaunch(
          launchUrl: Uri.parse(data['launchUrl'] as String),
          widgetOrigin: widget.widgetOrigin,
          registeredReturnUrl: widget.returnUrl!,
        );
        _links = AppLinks().uriLinkStream.listen(
          (uri) {
            if (_hosted?.handleReturn(uri) == true && mounted) {
              _finish(LuliVerifyResultStatus.hostedReturned);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _errorCode = 'return_link_unavailable');
          },
        );
        await _hosted!.open();
      }
      if (mounted) setState(() {});
    } catch (error) {
      _pendingClient?.close();
      _pendingClient = null;
      if (mounted) {
        setState(
          () => _errorCode = error is LuliVerifyException
              ? error.code
              : 'launch_failed',
        );
      }
    }
  }

  /// Closes the SDK route with advisory, sanitized session/navigation metadata.
  void _finish(LuliVerifyResultStatus status) {
    Navigator.of(context).pop(
      LuliVerifyResult(
        status: status,
        sessionId: _sessionId,
        testOnly: _testOnly,
        errorCode: _errorCode,
      ),
    );
  }

  /// Confirms leaving and attempts native cancellation only when mutation is safe.
  ///
  /// Hosted dismissal does not claim to cancel the remote browser session.
  Future<void> _close() async {
    if (_closing) return;
    if (_errorCode != null && _controller == null) {
      _finish(LuliVerifyResultStatus.error);
      return;
    }
    final controller = _controller;
    final session = controller?.session;
    if (session?.isTerminal == true) {
      _finish(switch (session!.status.name) {
        'completed' => LuliVerifyResultStatus.completed,
        'failed' => LuliVerifyResultStatus.failed,
        'cancelled' => LuliVerifyResultStatus.cancelled,
        _ => LuliVerifyResultStatus.expired,
      });
      return;
    }
    if (controller?.phase == LuliVerifySessionPhase.expired) {
      _finish(LuliVerifyResultStatus.expired);
      return;
    }
    if (controller?.phase == LuliVerifySessionPhase.submitting) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Leave verification?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your verification may be incomplete. You can stay and finish the remaining steps.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
              LuliButton(
                label: 'Keep verifying',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 12),
              LuliButton(
                label: 'Leave verification',
                secondary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave != true || !mounted) return;
    _closing = true;
    if (controller?.phase == LuliVerifySessionPhase.ready) {
      await controller!.cancel();
    }
    if (!mounted) return;
    _finish(
      controller?.session?.status.name == 'cancelled'
          ? LuliVerifyResultStatus.cancelled
          : _errorCode != null
          ? LuliVerifyResultStatus.error
          : LuliVerifyResultStatus.dismissed,
    );
  }

  @override
  void dispose() {
    _pendingClient?.close();
    _links?.cancel();
    _controller?.dispose();
    if (_controller == null) _transport?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: _controller != null && _transport != null && _errorCode == null
        ? LuliVerifySessionScreen(
            controller: _controller!,
            transport: _transport!,
            onClose: _close,
          )
        : Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(
                        tooltip: 'Close verification',
                        onPressed: _close,
                        icon: const Icon(LucideIcons.x),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _errorCode != null
                          ? LucideIcons.circleAlert
                          : _hosted != null
                          ? LucideIcons.externalLink
                          : LucideIcons.shieldCheck,
                      size: 52,
                      color: LuliVerifyDesign.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _errorCode != null
                          ? 'Unable to start verification'
                          : _hosted != null
                          ? 'Continue in your browser'
                          : 'Preparing your verification',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorCode != null
                          ? 'Check your connection and integration settings, then start again.'
                          : _hosted != null
                          ? 'Complete the steps in your browser. The registered return link will bring you back here.'
                          : 'Getting the steps required for your workflow.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: LuliVerifyDesign.muted,
                      ),
                    ),
                    if (_errorCode == null && _hosted == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    const Spacer(),
                    const LuliPoweredBy(),
                    if (_errorCode != null || _hosted != null)
                      LuliButton(label: 'Return to app', onPressed: _close),
                  ],
                ),
              ),
            ),
          ),
  );
}
