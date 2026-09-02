import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';

class CircleRecording {
  const CircleRecording({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// In-app circular camera, Telegram-style, with gallery-camera fallback.
Future<CircleRecording?> recordCircleVideo(BuildContext context) {
  return Navigator.of(context).push<CircleRecording>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CircleRecorderScreen(),
    ),
  );
}

class CircleRecorderScreen extends StatefulWidget {
  const CircleRecorderScreen({super.key});

  @override
  State<CircleRecorderScreen> createState() => _CircleRecorderScreenState();
}

class _CircleRecorderScreenState extends State<CircleRecorderScreen> {
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  String? _error;
  bool _recording = false;
  bool _switching = false;
  DateTime? _started;
  Timer? _ticker;
  double _zoom = 1.0;
  double _maxZoom = 4.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera({int? preferIndex}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'no-camera');
        return;
      }
      _cameras = cameras;
      var index = preferIndex ??
          cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (index < 0) index = 0;
      await _openCameraAt(index);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openCameraAt(int index) async {
    final old = _camera;
    _camera = null;
    await old?.dispose();
    if (!mounted) return;

    final description = _cameras[index];
    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    try {
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = await controller.getMinZoomLevel();
    } catch (_) {
      _maxZoom = 4.0;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _cameraIndex = index;
      _error = null;
      _switching = false;
    });
  }

  Future<void> _flipCamera() async {
    if (_recording || _switching || _cameras.length < 2) return;
    setState(() => _switching = true);
    final next = (_cameraIndex + 1) % _cameras.length;
    try {
      await _openCameraAt(next);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _switching = false;
        });
      }
    }
  }

  Future<void> _fallbackPick() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.pop(
      context,
      CircleRecording(bytes: bytes, name: file.name),
    );
  }

  Future<void> _cancelRecord() async {
    final camera = _camera;
    _ticker?.cancel();
    if (_recording && camera != null) {
      try {
        await camera.stopVideoRecording();
      } catch (_) {}
    }
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _sendRecord() async {
    await _toggleRecord();
  }

  Future<void> _toggleRecord() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _fallbackPick();
      return;
    }
    if (_recording) {
      _ticker?.cancel();
      try {
        final file = await camera.stopVideoRecording();
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        Navigator.pop(
          context,
          CircleRecording(bytes: bytes, name: file.name),
        );
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      }
      return;
    }
    try {
      await camera.startVideoRecording();
      _started = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
        final started = _started;
        if (started != null &&
            DateTime.now().difference(started).inSeconds >= 60) {
          _toggleRecord();
        }
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  String _elapsed() {
    final started = _started;
    if (started == null) return '0:00';
    final sec = DateTime.now().difference(started).inSeconds.clamp(0, 60);
    return '0:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(strings.circleRecordTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipOval(
                  child: camera != null && camera.value.isInitialized
                      ? GestureDetector(
                          onScaleStart: (_) => _baseZoom = _zoom,
                          onScaleUpdate: (details) async {
                            if (_camera == null) return;
                            final v = (_baseZoom * details.scale)
                                .clamp(1.0, _maxZoom);
                            try {
                              await _camera!.setZoomLevel(v);
                              if (mounted) setState(() => _zoom = v);
                            } catch (_) {}
                          },
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: camera.value.previewSize?.height ?? 320,
                              height: camera.value.previewSize?.width ?? 320,
                              child: CameraPreview(camera),
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: MurkotColors.night,
                          child: Center(
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      strings.circleCameraFallback,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  Text(
                    '${strings.recording} ${_elapsed()} / 1:00',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Щипок — зум  ${_zoom.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_recording)
                  IconButton(
                    onPressed: _cancelRecord,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Отмена',
                  )
                else
                  TextButton(
                    onPressed: _fallbackPick,
                    child: Text(strings.circleUseSystemCamera,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _recording ? Colors.redAccent : Colors.white24,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                if (_recording)
                  IconButton(
                    onPressed: _sendRecord,
                    icon: const Icon(Icons.send, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: const CircleBorder(),
                    ),
                    tooltip: 'Отправить',
                  )
                else
                  IconButton(
                    onPressed: _cameras.length > 1 && !_switching
                        ? _flipCamera
                        : null,
                    icon: Icon(
                      Icons.cameraswitch_rounded,
                      color: _cameras.length > 1
                          ? Colors.white
                          : Colors.white24,
                    ),
                    tooltip: strings.isRu
                        ? 'Сменить камеру'
                        : 'Flip camera',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
