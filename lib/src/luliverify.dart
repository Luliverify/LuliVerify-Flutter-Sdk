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
import 'presentation/hosted/hosted_launch.dart';
import 'presentation/native/session_screen.dart';

enum LuliVerifyResultStatus {
  completed,
  failed,
  cancelled,
  expired,
  dismissed,
  hostedReturned,
  error,
}

/// Advisory session/navigation result. Never use this as account authorization.
final class LuliVerifyResult {
  const LuliVerifyResult({
    required this.status,
    this.sessionId,
    this.testOnly,
    this.errorCode,
  });
  final LuliVerifyResultStatus status;
  final String? sessionId;
  final bool? testOnly;
  final String? errorCode;
}

/// Single-call launcher. Owns session, route, controllers and disposal.
abstract final class LuliVerify {
  static bool _launching = false;
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
                    if (_errorCode != null || _hosted != null)
                      LuliButton(label: 'Return to app', onPressed: _close),
                  ],
                ),
              ),
            ),
          ),
  );
}
