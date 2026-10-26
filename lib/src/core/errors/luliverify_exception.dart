/// SDK-local failures; never include tokens, images or personal data in messages.
final class LuliVerifyException implements Exception {
  const LuliVerifyException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'LuliVerifyException($code): $message';
}
