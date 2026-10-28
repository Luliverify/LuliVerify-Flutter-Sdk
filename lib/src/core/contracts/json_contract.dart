import '../errors/luliverify_exception.dart';

/// Throws a sanitized SDK contract error without exposing the rejected payload.
Never invalidContract() => throw const LuliVerifyException(
  'invalid_contract',
  'The server returned an invalid session contract.',
);

/// Validates string-keyed JSON object data and recursively freezes its values.
///
/// Throws LuliVerifyException for unsupported data; never logs the payload.
Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    invalidContract();
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key as String, freezeJson(item))),
  );
}

/// Recursively freezes supported JSON values; rejects non-finite/non-JSON data.
Object? freezeJson(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeJson));
  if (value is Map) return jsonObject(value);
  return invalidContract();
}

/// Requires a non-empty string; throws the standard contract error otherwise.
String jsonString(Object? value) {
  if (value is! String || value.isEmpty) invalidContract();
  return value;
}

/// Requires a JSON boolean; throws the standard contract error otherwise.
bool jsonBool(Object? value) {
  if (value is! bool) invalidContract();
  return value;
}

/// Requires a non-negative integer, without coercing strings or decimals.
int jsonInteger(Object? value) {
  if (value is! int || value < 0) invalidContract();
  return value;
}

/// Requires a JSON list and returns an unmodifiable shallow copy.
List<Object?> jsonList(Object? value) {
  if (value is! List) invalidContract();
  return List.unmodifiable(value);
}

/// Compares JSON structures deeply; map order is ignored and list order matters.
bool sameJson(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && sameJson(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(
          left.length,
          (i) => i,
        ).every((i) => sameJson(left[i], right[i]));
  }
  return left == right;
}
