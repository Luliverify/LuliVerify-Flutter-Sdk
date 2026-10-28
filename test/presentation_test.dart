import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/src/presentation/design/presentation_labels.dart';
import 'package:luliverify_flutter/src/presentation/design/session_states.dart';
import 'package:luliverify_flutter/src/presentation/design/luli_components.dart';
import 'package:luliverify_flutter/src/presentation/native/selfie_capture_screen.dart';

void main() {
  test(
    'labels preserve values, respect server labels and support older servers',
    () {
      expect(presentationOptions(['nin', 'drivers_license'], null), {
        'nin': 'NIN',
        'drivers_license': 'Driver’s licence',
      });
      expect(
        presentationOptions(
          ['front'],
          [
            {'value': 'front', 'label': 'Front of document'},
            {'value': 'injected', 'label': 'Invalid'},
          ],
        ),
        {'front': 'Front of document'},
      );
      expect(presentationLabel('document_upload'), 'Document upload');
      expect(presentationLabel('national_id'), 'National ID');
    },
  );
  for (final variant in [
    'expired',
    'expired-large-text',
    'expired-landscape',
    'welcome',
  ]) {
    testWidgets('$variant has a readable, scroll-safe SDK layout', (
      tester,
    ) async {
      tester.view.physicalSize = variant == 'expired-landscape'
          ? const Size(844, 390)
          : Size(variant == 'expired-large-text' ? 320 : 390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('packages/luliverify_flutter/Geist')..addFont(
            rootBundle.load(
              'packages/luliverify_flutter/assets/fonts/Geist.ttf',
            ),
          ))
          .load();
      await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          ))
          .load();
      final boundary = GlobalKey();
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: LuliVerifyDesign.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                variant == 'expired-large-text' ? 1.6 : 1,
              ),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: LuliVerifyDesign.ink,
                elevation: 0,
                title: const Text('LuliVerify'),
              ),
              body: SafeArea(
                child: variant == 'welcome'
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          const Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Follow the steps below to submit your information.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: LuliVerifyDesign.muted,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const LuliWelcomeIntro(),
                          LuliButton(label: 'Continue', onPressed: () {}),
                          const LuliPoweredBy(),
                        ],
                      )
                    : LuliTerminalView(
                        expired: true,
                        completed: false,
                        cancelled: false,
                        onClose: () => closed = true,
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Powered by ', findRichText: true),
        findsOneWidget,
      );
      if (variant != 'welcome') {
        await tester.ensureVisible(find.text('Return to app'));
        await tester.tap(find.text('Return to app'));
        expect(closed, true);
      }
      if (Platform.environment['DESIGN_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/private/tmp/luliverify-$variant.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('face guide paints in portrait and landscape', (tester) async {
    for (final size in [const Size(260, 340), const Size(440, 230)]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: const CustomPaint(painter: LuliFaceGuidePainter()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
