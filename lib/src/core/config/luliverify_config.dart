/// Desired presentation; availability must be confirmed by the backend.
enum LuliVerifyPresentation { nativeUi, hostedWeb }

/// Non-secret SDK configuration. Never put merchant credentials here.
final class LuliVerifyConfig {
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
  final Uri apiBaseUrl;
  final LuliVerifyPresentation presentation;
}
