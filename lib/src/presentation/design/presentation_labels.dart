/// Formats a legacy LuliVerify value for display without changing its wire value.
///
/// Known document acronyms/names receive readable labels. New server-provided
/// presentation metadata takes precedence in the calling widgets.
String presentationLabel(String value) {
  const labels = {
    'nin': 'NIN',
    'bvn': 'BVN',
    'tin': 'TIN',
    'drivers_license': 'Driver’s licence',
    'passport': 'International passport',
    'voter_card': 'Voter’s card',
    'national_id': 'National ID',
    'cac_certificate': 'CAC certificate',
    'memorandum': 'Memorandum of association',
    'tax_certificate': 'Tax certificate',
    'proof': 'Proof of address',
    'welcome': 'Welcome',
    'completion': 'Complete verification',
    'liveness': 'Liveness check',
  };
  if (labels.containsKey(value)) return labels[value]!;
  final text = value.replaceAll('_', ' ');
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

/// Combines allowed [values] with optional server label metadata.
///
/// Preserves allowed values/order, ignores metadata for other values, and falls
/// back to readable legacy labels. Never submit these labels as LuliVerify values.
Map<String, String> presentationOptions(List<String> values, Object? metadata) {
  final labels = <String, String>{};
  if (metadata is List) {
    for (final option in metadata.whereType<Map>()) {
      if (option['value'] is String &&
          option['label'] is String &&
          (option['label'] as String).trim().isNotEmpty) {
        labels[option['value'] as String] = option['label'] as String;
      }
    }
  }
  return {
    for (final value in values)
      value: labels[value] ?? presentationLabel(value),
  };
}
