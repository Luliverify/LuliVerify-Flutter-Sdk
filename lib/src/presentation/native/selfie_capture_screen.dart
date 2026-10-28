import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/luli_components.dart';
import '../design/session_states.dart';

/// Internal front-camera capture/review route with a dotted framing guide.
///
/// Returns a newly captured XFile when accepted, or null on dismissal. No face
/// detection or liveness outcome is produced. Not exported as the primary SDK API.
class LuliSelfieCaptureScreen extends StatefulWidget {
  /// Creates the camera route; permissions are requested when the camera initializes.
  const LuliSelfieCaptureScreen({super.key});
  @override
  State<LuliSelfieCaptureScreen> createState() => _SelfieCaptureState();
}

/// Owns camera lifecycle, temporary capture and in-memory review preview.
class _SelfieCaptureState extends State<LuliSelfieCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  XFile? _photo;
  Uint8List? _preview;
  String? _error;
  bool _busy = false;
  bool _active = true;
  int _generation = 0;
  Future<void> _pending = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  /// Serializes front-camera initialization and discards stale lifecycle generations.
  void _open() {
    final generation = ++_generation;
    _pending = _pending.then((_) async {
      final old = _camera;
      _camera = null;
      await old?.dispose();
      if (!mounted || !_active || _photo != null || generation != _generation) {
        return;
      }
      CameraController? next;
      try {
        final cameras = await availableCameras();
        final front = cameras
            .where(
              (camera) => camera.lensDirection == CameraLensDirection.front,
            )
            .firstOrNull;
        if (front == null) {
          throw CameraException('unavailable', 'No front camera');
        }
        next = CameraController(
          front,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await next.initialize();
        if (!mounted || !_active || generation != _generation) {
          await next.dispose();
          return;
        }
        setState(() {
          _camera = next;
          _error = null;
        });
      } catch (error) {
        await next?.dispose();
        if (mounted && generation == _generation) {
          setState(
            () =>
                _error = error is CameraException && error.code == 'unavailable'
                ? 'A front camera is required. Use a device with a front camera to continue.'
                : 'Camera unavailable. Allow camera access in your device settings, then try again.',
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _active = false;
      ++_generation;
      final camera = _camera;
      _camera = null;
      _pending = _pending.then((_) async {
        await camera?.dispose();
      });
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _active = true;
      _open();
    }
  }

  /// Captures a temporary file and reads its review bytes before releasing camera.
  ///
  /// The memory preview avoids file-load races when a customer rapidly retakes.
  Future<void> _capture() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final photo = await camera.takePicture();
      Uint8List preview;
      try {
        preview = await photo.readAsBytes();
      } catch (_) {
        await _delete(photo);
        rethrow;
      }
      if (!mounted) {
        await _delete(photo);
        return;
      }
      setState(() {
        _photo = photo;
        _preview = preview;
      });
      _camera = null;
      await camera.dispose();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to take a photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Best-effort cleanup of an operation-owned temporary camera file.
  Future<void> _delete(XFile? photo) async {
    if (photo == null) return;
    try {
      await File(photo.path).delete();
    } catch (_) {
      /* OS cache cleanup. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    final camera = _camera;
    _pending = _pending.then((_) async {
      await camera?.dispose();
    });
    _delete(_photo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'Cancel photo',
                      icon: const Icon(LucideIcons.x),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    _photo == null
                        ? 'Position your face inside the guide'
                        : 'Is your face clear?',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _photo == null
                        ? 'Face the camera in good lighting. Keep your eyes visible and hold still.'
                        : 'Use this photo or retake it if it’s blurred or poorly lit.',
                    style: const TextStyle(
                      color: LuliVerifyDesign.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: .85,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: ColoredBox(
                        color: const Color(0xff151923),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_photo != null)
                              Image.memory(
                                _preview!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text(
                                    'Unable to preview this photo. Please retake it.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                            else if (_camera?.value.isInitialized == true)
                              Center(
                                child: AspectRatio(
                                  aspectRatio: 1 / _camera!.value.aspectRatio,
                                  child: CameraPreview(_camera!),
                                ),
                              )
                            else if (_error != null)
                              const Center(
                                child: Icon(
                                  LucideIcons.cameraOff,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              )
                            else if (!_active)
                              const Center(
                                child: Text(
                                  'Camera paused',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            else
                              const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            if (_photo == null)
                              const IgnorePointer(
                                child: CustomPaint(
                                  painter: LuliFaceGuidePainter(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    LuliNotice(_error!, error: true),
                    LuliButton(
                      label: 'Retry camera',
                      secondary: true,
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _error = null);
                              _open();
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_photo == null)
                    LuliButton(
                      label: 'Capture photo',
                      icon: LucideIcons.camera,
                      busy: _busy,
                      onPressed: _camera?.value.isInitialized == true && !_busy
                          ? _capture
                          : null,
                    )
                  else ...[
                    LuliButton(
                      label: 'Use photo',
                      onPressed: _busy
                          ? null
                          : () {
                              final photo = _photo;
                              _photo = null;
                              _preview = null;
                              Navigator.of(context).pop(photo);
                            },
                    ),
                    const SizedBox(height: 12),
                    LuliButton(
                      label: 'Retake photo',
                      secondary: true,
                      onPressed: _busy
                          ? null
                          : () async {
                              final photo = _photo;
                              setState(() {
                                _photo = null;
                                _preview = null;
                              });
                              await _delete(photo);
                              if (mounted) _open();
                            },
                    ),
                  ],
                  const LuliPoweredBy(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Paints a shaded exterior and dotted oval for camera framing only.
class LuliFaceGuidePainter extends CustomPainter {
  /// Creates the geometry-only guide painter; no image analysis is performed.
  const LuliFaceGuidePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .48),
      width: size.width * .72,
      height: size.height * .76,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(rect);
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: .42),
    );
    final path = Path()..addOval(rect);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 13) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 3, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LuliFaceGuidePainter oldDelegate) => false;
}
