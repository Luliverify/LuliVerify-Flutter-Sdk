import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/luliverify_exception.dart';

/// Opens a server-minted widget launch. Return navigation is not approval.
final class LuliVerifyHostedLaunch {
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
  final Uri registeredReturnUrl;
  late final String sessionId;
  bool _opened = false;
  bool _returned = false;

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

  /// Host app forwards OS-verified universal/app links here. Exact matching is
  /// intentional: register a distinct server-bound return URL per launch.
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
