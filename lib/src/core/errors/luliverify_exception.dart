/// SDK-local failures; never include tokens, images or personal data in messages.
final class LuliVerifyException implements Exception {
  /// Creates an SDK failure with a machine-readable [code] and safe [message].
  ///
  /// Callers constructing their own errors must exclude credentials, evidence,
  /// personal data, and raw provider responses.
  const LuliVerifyException(this.code, this.message);

  /// Machine-readable SDK category; not a raw provider error code.
  final String code;

  /// Human-readable recovery context without sensitive payloads.
  final String message;
  @override
  /// Formats the SDK category and message; never add private data to either field.
  String toString() => 'LuliVerifyException($code): $message';
}
