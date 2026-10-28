/// Presentation requested for a workflow launch.
///
/// A mode is explicit; unsupported native checks do not fall back to hosted web.
enum LuliVerifyPresentation {
  /// Render LuliVerify-driven fields and evidence using native Flutter screens.
  nativeUi,

  /// Open the hosted website externally; verified app-return links are required.
  hostedWeb,
}

/// Validated, non-secret API configuration for low-level SDK adapters.
///
/// Use LuliVerify.launch for the normal integration. Never store private merchant
/// credentials, launch tickets, or session tokens in this object.
final class LuliVerifyConfig {
  /// Creates configuration for [apiBaseUrl] and [presentation].
  ///
  /// The base may contain a path prefix. Throws [ArgumentError] unless it is HTTPS
  /// with a host and without user information, query parameters, or a fragment.
  LuliVerifyConfig({
    required this.apiBaseUrl,
    this.presentation = LuliVerifyPresentation.nativeUi,
  }) {
    if (apiBaseUrl.scheme != 'https' ||
        !apiBaseUrl.hasAuthority ||
        apiBaseUrl.host.isEmpty ||
        apiBaseUrl.userInfo.isNotEmpty ||
        apiBaseUrl.hasQuery ||
        apiBaseUrl.hasFragment) {
      throw ArgumentError(
        'apiBaseUrl must be HTTPS without credentials, query or fragment',
      );
    }
  }

  /// HTTPS API base to which session endpoint paths are appended.
  final Uri apiBaseUrl;

  /// Selected presentation, defaulting to native UI.
  final LuliVerifyPresentation presentation;
}
