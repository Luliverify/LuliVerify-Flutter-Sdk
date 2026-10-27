import '../errors/luliverify_exception.dart';

Never invalidContract() => throw const LuliVerifyException(
  'invalid_contract',
  'The server returned an invalid session contract.',
);

Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    invalidContract();
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key as String, freezeJson(item))),
  );
}

Object? freezeJson(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeJson));
  if (value is Map) return jsonObject(value);
  return invalidContract();
}

String jsonString(Object? value) {
  if (value is! String || value.isEmpty) invalidContract();
  return value;
}

bool jsonBool(Object? value) {
  if (value is! bool) invalidContract();
  return value;
}

int jsonInteger(Object? value) {
  if (value is! int || value < 0) invalidContract();
  return value;
}

List<Object?> jsonList(Object? value) {
  if (value is! List) invalidContract();
  return List.unmodifiable(value);
}

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
