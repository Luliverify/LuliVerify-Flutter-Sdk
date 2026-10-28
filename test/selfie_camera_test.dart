import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luliverify_flutter/src/presentation/design/luli_components.dart';
import 'package:luliverify_flutter/src/presentation/native/selfie_capture_screen.dart';

class TestPhoto extends XFile {
  TestPhoto(super.path);
  @override
  Future<Uint8List> readAsBytes() async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
  );
}

class TestCamera extends CameraPlatform {
  bool denied = false;
  CameraLensDirection? selectedLens;
  bool? audio;
  bool noFront = false;
  int created = 0, disposed = 0;
  final photos = <File>[];
  late File prepared;
  final errors = StreamController<CameraErrorEvent>.broadcast();
  @override
  Future<List<CameraDescription>> availableCameras() async {
    if (denied) throw CameraException('CameraAccessDenied', 'Denied');
    return [
      CameraDescription(
        name: 'test',
        lensDirection: noFront
            ? CameraLensDirection.back
            : CameraLensDirection.front,
        sensorOrientation: 90,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    selectedLens = cameraDescription.lensDirection;
    audio = mediaSettings.enableAudio;
    return ++created;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.grey);
  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final file = prepared;
    photos.add(file);
    return TestPhoto(file.path);
  }
}

void main() {
  late CameraPlatform old;
  late TestCamera camera;
  setUp(() async {
    old = CameraPlatform.instance;
    camera = TestCamera();
    CameraPlatform.instance = camera;
    camera.prepared = File('${Directory.systemTemp.path}/luli-camera-test.png');
    await camera.prepared.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aL1sAAAAASUVORK5CYII=',
      ),
    );
  });
  tearDown(() async {
    CameraPlatform.instance = old;
    for (final file in camera.photos) {
      if (await file.exists()) await file.delete();
    }
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LuliVerifyDesign.theme(),
        home: const LuliSelfieCaptureScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'denied access and unavailable front camera offer recovery, never capture',
    (tester) async {
      camera.denied = true;
      await open(tester);
      expect(find.textContaining('Camera unavailable.'), findsOneWidget);
      expect(camera.created, 0);
      camera.denied = false;
      camera.noFront = true;
      await tester.ensureVisible(find.text('Retry camera'));
      await tester.tap(find.text('Retry camera'));
      await tester.pumpAndSettle();
      expect(camera.created, 0);
      expect(
        find.textContaining('A front camera is required.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('camera releases on interruption and reopens on return', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(AppBar), findsNothing);
    expect(find.textContaining('Simulated'), findsNothing);
    expect(camera.created, 1);
    expect(camera.selectedLens, CameraLensDirection.front);
    expect(camera.audio, false);
    (tester.state(find.byType(LuliSelfieCaptureScreen)) as dynamic)
        .didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    expect(camera.disposed, 1);
    (tester.state(find.byType(LuliSelfieCaptureScreen)) as dynamic)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(camera.created, 2);
    expect(find.textContaining('Camera unavailable.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(camera.disposed, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'captured photos require review and retake deletes the old capture',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('Capture photo'));
      await tester.tap(find.text('Capture photo'));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
      }
      await tester.pumpAndSettle();
      expect(find.text('Use photo'), findsOneWidget);
      expect(find.text('Retake photo'), findsOneWidget);
      expect(camera.disposed, 1);
      final retake = find.byWidgetPredicate(
        (widget) => widget is LuliButton && widget.label == 'Retake photo',
      );
      await tester.ensureVisible(retake);
      await tester.pumpAndSettle();
      expect(tester.widget<LuliButton>(retake).onPressed, isNotNull);
      await tester.tap(retake);
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
      }
      await tester.pumpAndSettle();
      expect(camera.created, 2);
      expect(await tester.runAsync(() => camera.photos.single.exists()), false);
      expect(camera.created, 2);
      expect(find.text('Capture photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
