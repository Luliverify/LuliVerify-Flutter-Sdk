import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() {
  for (final variant in ['business', 'liveness', 'large-text']) {
    testWidgets(
      'native $variant layout uses backend fields and accessible custom controls',
      (tester) async {
        tester.view.physicalSize = Size(
          variant == 'large-text' ? 320 : 390,
          844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final json = jsonDecode(
          File(
            'test/fixtures/${variant == 'liveness' ? 'liveness' : 'business'}_session.json',
          ).readAsStringSync(),
        ) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        // Brand supplied by the user; session/contract content remains synthetic.
        data['branding']['primaryColor'] = '#1F3FE2';
        data['branding']['displayName'] = 'LuliVerify';
        data['accessChannel'] = 'native';
        data['sessionToken'] = 's' * 43;
        if (variant != 'liveness') {
          final contract = (data['inputContracts'] as Map).values.firstWhere(
            (c) => c['toolType'] == 'cac',
          );
          contract['submission']['scenario'] = {
            'source': 'workflow',
            'customerEditable': false,
          };
          final step = {
            'id': contract['stepId'],
            'type': 'cac',
            'title': 'Business details',
            'description': 'Enter the company details shown on your registration document.',
            'inputContract': contract,
          };
          data['currentStep'] = step;
          data['availableSubTools'] = [step];
        }
        final font = FontLoader('packages/luliverify_flutter/Geist')
          ..addFont(
            rootBundle.load(
              'packages/luliverify_flutter/assets/fonts/Geist.ttf',
            ),
          );
        await font.load();
        final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          );
        await icons.load();
        final transport = await LuliVerifyNativeSessionTransport.connect(
          config: LuliVerifyConfig(
            apiBaseUrl: Uri.parse('https://api.example.com'),
          ),
          grant: LuliVerifyNativeGrant.fromJson({
            'sessionId': data['id'],
            'ticket': 'n' * 43,
            'ticketExpiresAt': '2099-01-01T00:00:00Z',
            'accessChannel': 'native',
          }),
          client: MockClient((_) async => http.Response(jsonEncode(json), 200)),
        );
        final controller = LuliVerifySessionController(
          sessionId: transport.sessionId,
          transport: transport,
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  variant == 'large-text' ? 1.6 : 1,
                ),
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: LuliVerifySessionScreen(
                controller: controller,
                transport: transport,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (variant != 'liveness') {
          expect(find.text('Company registration number'), findsOneWidget);
          // The custom selection sheet uses exactly the server options.
          await tester.ensureVisible(find.text('Basic'));
          await tester.tap(find.text('Basic'));
          await tester.pumpAndSettle();
          expect(find.text('Advanced'), findsOneWidget);
          Navigator.of(tester.element(find.text('Advanced'))).pop();
          await tester.pumpAndSettle();
        }
        if (Platform.environment['DESIGN_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('/private/tmp/luliverify-$variant.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
