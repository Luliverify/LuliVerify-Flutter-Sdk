import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';

class FakeLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;
  bool fail = false;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (fail) throw Exception('ticket-must-not-leak');
    return true;
  }
}

LuliVerifyHostedLaunch launch({
  String host = 'verify.example.com',
  String? fragment,
}) => LuliVerifyHostedLaunch(
  launchUrl: Uri.parse(
    'https://$host/#${fragment ?? 'sessionId=670100000000000000000003&ticket=${'a' * 43}'}',
  ),
  widgetOrigin: Uri.parse('https://verify.example.com'),
  registeredReturnUrl: Uri.parse(
    'https://merchant.example/return?state=server-bound-state',
  ),
);
void main() {
  late UrlLauncherPlatform previous;
  late FakeLauncher fake;
  setUp(() {
    previous = UrlLauncherPlatform.instance;
    fake = FakeLauncher();
    UrlLauncherPlatform.instance = fake;
  });
  tearDown(() => UrlLauncherPlatform.instance = previous);
  test('validates hosted origin and rejects duplicate parameters', () {
    expect(() => launch(host: 'attacker.example'), throwsArgumentError);
    expect(
      () => launch(
        fragment:
            'sessionId=670100000000000000000003&ticket=${'a' * 43}&ticket=${'b' * 43}',
      ),
      throwsArgumentError,
    );
  });
  test('accepts exactly one matching app return only after opening', () async {
    final value = launch();
    final link = Uri.parse(
      'https://merchant.example/return?state=server-bound-state',
    );
    expect(value.handleReturn(link), false);
    await value.open();
    expect(
      value.handleReturn(
        Uri.parse('https://merchant.example/return?state=wrong'),
      ),
      false,
    );
    expect(value.handleReturn(link), true);
    expect(value.handleReturn(link), false);
    await expectLater(value.open(), throwsA(isA<LuliVerifyException>()));
  });
  test('redacts browser errors', () async {
    fake.fail = true;
    await expectLater(
      launch().open(),
      throwsA(
        isA<LuliVerifyException>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('ticket-must-not-leak')),
        ),
      ),
    );
  });
}
