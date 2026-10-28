import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/luliverify_exception.dart';

/// Single-use external-browser launcher for a backend-minted hosted session.
///
/// This low-level adapter neither creates sessions nor registers/listens for OS
/// app links. Prefer LuliVerify.launch for the managed browser/listener flow.
/// Returning to the app is navigation and never proof of verification approval.
final class LuliVerifyHostedLaunch {
  /// Validates a hosted [launchUrl] against the expected [widgetOrigin].
  ///
  /// The URL must contain exactly one sessionId and one opaque ticket in its
  /// fragment. All supplied URLs must be HTTPS without credentials;
  /// [registeredReturnUrl] must have no fragment. Invalid values throw
  /// [ArgumentError]. Backend allowlisting and app/domain association are still
  /// required; construction does not install them. Never log the launch URL.
  LuliVerifyHostedLaunch({
    required Uri launchUrl,
    required Uri widgetOrigin,
    required this.registeredReturnUrl,
  }) : _launchUrl = launchUrl {
    for (final url in [launchUrl, widgetOrigin, registeredReturnUrl]) {
      if (url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw ArgumentError('Hosted URLs must use HTTPS without credentials.');
      }
    }
    if (launchUrl.origin != widgetOrigin.origin ||
        registeredReturnUrl.hasFragment) {
      throw ArgumentError('Invalid hosted launch or return URL.');
    }
    final fragment = Uri.splitQueryString(launchUrl.fragment);
    final all = Uri(query: launchUrl.fragment).queryParametersAll;
    if (all.length != 2 ||
        !all.keys.toSet().containsAll({'sessionId', 'ticket'}) ||
        all.values.any((values) => values.length != 1)) {
      throw ArgumentError('Invalid widget launch parameters.');
    }
    sessionId = fragment['sessionId'] ?? '';
    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(sessionId) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(fragment['ticket'] ?? '')) {
      throw ArgumentError('A server-minted widget launch is required.');
    }
  }
  Uri? _launchUrl;

  /// Complete registered return URI; incoming links must match its exact string.
  final Uri registeredReturnUrl;

  /// Session identifier parsed from the backend-minted launch URL.
  late final String sessionId;
  bool _opened = false;
  bool _returned = false;

  /// Opens the launch URL once using the device’s external browser.
  ///
  /// The URL is consumed before opening. Throws LuliVerifyException when it was
  /// already used or browser launch fails; request fresh authorization rather
  /// than replaying the original URL. Does not wait for workflow completion.
  Future<void> open() async {
    final url = _launchUrl;
    if (url == null) {
      throw const LuliVerifyException(
        'launch_consumed',
        'Obtain a fresh hosted launch from your server.',
      );
    }
    _launchUrl = null;
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const LuliVerifyException(
          'browser_unavailable',
          'The hosted session could not be opened.',
        );
      }
    } catch (_) {
      throw const LuliVerifyException(
        'browser_unavailable',
        'The hosted session could not be opened.',
      );
    }
    _opened = true;
  }

  /// Accepts one exact return URI only after a successful browser open.
  ///
  /// [incoming] should come from OS-verified App/Universal Link delivery. Returns
  /// false for early, foreign, mismatched or repeated links. Does not fetch session
  /// results, restore tokens, validate identity, or authorize the customer.
  bool handleReturn(Uri incoming) {
    if (!_opened ||
        _returned ||
        incoming.toString() != registeredReturnUrl.toString()) {
      return false;
    }
    _returned = true;
    return true;
  }
}
