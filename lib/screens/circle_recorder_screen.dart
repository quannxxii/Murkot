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
  bool _paused = false;
  bool _switching = false;
  Duration _recorded = Duration.zero;
  DateTime? _segmentStarted;
  Timer? _ticker;
  double _zoom = 1.0;
  double _maxZoom = 4.0;
  double _baseZoom = 1.0;

  bool get _sessionActive => _recording || _paused;

  Duration get _totalRecorded {
    var total = _recorded;
    if (_recording && !_paused && _segmentStarted != null) {
      total += DateTime.now().difference(_segmentStarted!);
    }
    return total;
  }

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
    if (_sessionActive || _switching || _cameras.length < 2) return;
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

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
      if (_totalRecorded.inSeconds >= 60) {
        _stopAndSend();
      }
    });
  }

  Future<void> _cancelRecord() async {
    final camera = _camera;
    _ticker?.cancel();
    if (_sessionActive && camera != null) {
      try {
        await camera.stopVideoRecording();
      } catch (_) {}
    }
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _stopAndSend() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || !_sessionActive) {
      return;
    }
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
  }

  Future<void> _startRecord() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      await _fallbackPick();
      return;
    }
    try {
      await camera.startVideoRecording();
      _segmentStarted = DateTime.now();
      _startTicker();
      setState(() {
        _recording = true;
        _paused = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pauseRecord() async {
    final camera = _camera;
    if (camera == null || !_recording || _paused) return;
    try {
      await camera.pauseVideoRecording();
      final started = _segmentStarted;
      if (started != null) {
        _recorded += DateTime.now().difference(started);
      }
      _segmentStarted = null;
      if (mounted) {
        setState(() {
          _paused = true;
          _recording = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _resumeRecord() async {
    final camera = _camera;
    if (camera == null || !_paused) return;
    try {
      await camera.resumeVideoRecording();
      _segmentStarted = DateTime.now();
      if (mounted) {
        setState(() {
          _paused = false;
          _recording = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _onCenterTap() async {
    if (!_sessionActive) {
      await _startRecord();
      return;
    }
    if (_paused) {
      await _resumeRecord();
    } else {
      await _pauseRecord();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  String _elapsed() {
    final sec = _totalRecorded.inSeconds.clamp(0, 60);
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
          if (_sessionActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  Text(
                    '${_paused ? (strings.isRu ? 'Пауза' : 'Paused') : strings.recording} ${_elapsed()} / 1:00',
                    style: TextStyle(
                      color: _paused ? Colors.amber : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.isRu
                        ? 'Щипок — зум  ${_zoom.toStringAsFixed(1)}x'
                        : 'Pinch to zoom  ${_zoom.toStringAsFixed(1)}x',
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
                if (_sessionActive)
                  IconButton(
                    onPressed: _cancelRecord,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: strings.isRu ? 'Отмена' : 'Cancel',
                  )
                else
                  TextButton(
                    onPressed: _fallbackPick,
                    child: Text(strings.circleUseSystemCamera,
                        style: const TextStyle(color: Colors.white70)),
                  ),
                GestureDetector(
                  onTap: _onCenterTap,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _sessionActive ? Colors.white : Colors.white,
                        width: 4,
                      ),
                      color: _sessionActive
                          ? (_paused ? Colors.white24 : Colors.redAccent)
                          : Colors.white24,
                    ),
                    child: Icon(
                      !_sessionActive
                          ? Icons.fiber_manual_record
                          : _paused
                              ? Icons.fiber_manual_record
                              : Icons.pause_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                if (_sessionActive)
                  IconButton(
                    onPressed: _stopAndSend,
                    icon: const Icon(Icons.send, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: const CircleBorder(),
                    ),
                    tooltip: strings.isRu ? 'Отправить' : 'Send',
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
