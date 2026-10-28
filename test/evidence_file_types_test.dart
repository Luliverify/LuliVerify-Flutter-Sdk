import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/src/platform/evidence_picker.dart';

void main() {
  test(
    'iOS document filters include UTIs and match the server MIME policy',
    () {
      final types = evidenceTypeGroup([
        'application/pdf',
        'image/png',
        'image/jpeg',
      ]);
      expect(types.uniformTypeIdentifiers, [
        'com.adobe.pdf',
        'public.png',
        'public.jpeg',
      ]);
      expect(types.extensions, ['pdf', 'png', 'jpg', 'jpeg']);
      expect(types.allowsAny, false);
    },
  );
  test('selfie policy cannot select PDFs through any platform filter', () {
    final types = evidenceTypeGroup(['image/jpeg']);
    expect(types.uniformTypeIdentifiers, ['public.jpeg']);
    expect(types.extensions, ['jpg', 'jpeg']);
    expect(types.mimeTypes, ['image/jpeg']);
  });
}
