import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() {
  test('configuration defaults to native presentation', () {
    final config = LuliVerifyConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
    );
    expect(config.presentation, LuliVerifyPresentation.nativeUi);
  });
  test('hosted presentation is explicit', () {
    final config = LuliVerifyConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
      presentation: LuliVerifyPresentation.hostedWeb,
    );
    expect(config.presentation, LuliVerifyPresentation.hostedWeb);
  });
  for (final url in [
    'http://api.example.com',
    '/relative',
    'https://user:secret@api.example.com',
    'https://api.example.com?token=secret',
    'https://api.example.com#secret',
  ]) {
    test('rejects unsafe base URL $url', () {
      expect(
        () => LuliVerifyConfig(apiBaseUrl: Uri.parse(url)),
        throwsArgumentError,
      );
    });
  }
}
