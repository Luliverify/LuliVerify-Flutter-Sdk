import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() {
  test(
    'Android read-only picker bytes can be cleared after successful upload',
    () {
      final platformBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])
          .asUnmodifiableView();
      final evidence = LuliVerifyPickedEvidence(platformBytes, 'image/png');
      expect(evidence.bytes, platformBytes);
      expect(
        () => evidence.bytes.fillRange(0, evidence.bytes.length, 0),
        returnsNormally,
      );
      expect(evidence.bytes, [0, 0, 0, 0]);
      expect(platformBytes, [0x89, 0x50, 0x4e, 0x47]);
    },
  );
  test('evidence cleanup does not modify the caller-owned file buffer', () {
    final original = Uint8List.fromList([1, 2, 3]);
    final evidence = LuliVerifyPickedEvidence(original, 'image/jpeg');
    evidence.bytes.fillRange(0, evidence.bytes.length, 0);
    expect(original, [1, 2, 3]);
  });
}
