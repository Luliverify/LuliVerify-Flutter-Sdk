/// Compatibility labels for older servers. New server labels take precedence.
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
