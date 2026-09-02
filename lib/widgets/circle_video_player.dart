import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'unlumen/murkot_fx.dart';

/// Telegram-style circular video note — tap pause/play, drag on the ring to seek.
class CircleVideoPlayer extends StatefulWidget {
  const CircleVideoPlayer({
    super.key,
    required this.url,
    this.size = 200,
  });

  final String url;
  final double size;

  @override
  State<CircleVideoPlayer> createState() => _CircleVideoPlayerState();
}

class _CircleVideoPlayerState extends State<CircleVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  bool _seeking = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _boot(widget.url);
  }

  Future<void> _boot(String url) async {
    final old = _controller;
    _controller = null;
    old?.removeListener(_onTick);
    await old?.dispose();
    if (!mounted) return;

    setState(() {
      _ready = false;
      _failed = false;
      _playing = false;
      _progress = 0;
    });

    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c.addListener(_onTick);
    try {
      await c.initialize();
      if (!mounted || _controller != c) return;
      await c.setLooping(false);
      await c.seekTo(Duration.zero);
      await c.play();
      if (!mounted || _controller != c) return;
      setState(() {
        _ready = true;
        _playing = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !_ready || !mounted || _seeking) return;
    final dur = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    var nextProgress = dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);
    var nextPlaying = c.value.isPlaying;

    // Stop at the end (no infinite loop).
    if (dur > 0 && pos >= dur - 80 && !c.value.isPlaying) {
      nextProgress = 1.0;
      nextPlaying = false;
    } else if (dur > 0 && pos >= dur - 80 && c.value.isPlaying) {
      c.pause();
      nextProgress = 1.0;
      nextPlaying = false;
    }

    if ((nextProgress - _progress).abs() > 0.002 || nextPlaying != _playing) {
      setState(() {
        _progress = nextProgress;
        _playing = nextPlaying;
      });
    }
  }

  @override
  void didUpdateWidget(covariant CircleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _boot(widget.url);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      await c.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      if (_progress >= 0.98) {
        await c.seekTo(Duration.zero);
        if (mounted) setState(() => _progress = 0);
      }
      await c.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  Future<void> _seekFraction(double fraction, {bool resume = false}) async {
    final c = _controller;
    if (c == null || !_ready) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    final ms = (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await c.seekTo(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() => _progress = fraction.clamp(0.0, 1.0));
    if (resume && !c.value.isPlaying) {
      await c.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  double? _fractionFromLocal(Offset local, double size) {
    final center = Offset(size / 2, size / 2);
    final v = local - center;
    final dist = v.distance;
    final outer = size / 2;
    // Only the ring band (~outer 28% of radius) seeks; center taps toggle.
    if (dist < outer * 0.62 || dist > outer * 1.08) return null;
    var angle = math.atan2(v.dy, v.dx); // 0 = right
    // Shift so 0 = top, clockwise.
    var frac = (angle + math.pi / 2) / (math.pi * 2);
    if (frac < 0) frac += 1;
    return frac.clamp(0.0, 1.0);
  }

  void _onSeekStart(Offset local, double size) {
    final frac = _fractionFromLocal(local, size);
    if (frac == null) return;
    _seeking = true;
    _seekFraction(frac);
  }

  void _onSeekUpdate(Offset local, double size) {
    if (!_seeking) {
      _onSeekStart(local, size);
      return;
    }
    final frac = _fractionFromLocal(local, size);
    if (frac == null) return;
    _seekFraction(frac);
  }

  Future<void> _onSeekEnd() async {
    if (!_seeking) return;
    _seeking = false;
    // Stay paused after scrub so user can fine-tune; tap to resume.
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_failed) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final frac = _fractionFromLocal(d.localPosition, size);
          if (frac != null) {
            // Tap on ring = seek + stay paused.
            _seekFraction(frac);
          } else {
            _toggle();
          }
        },
        onPanStart: (d) => _onSeekStart(d.localPosition, size),
        onPanUpdate: (d) => _onSeekUpdate(d.localPosition, size),
        onPanEnd: (_) => _onSeekEnd(),
        onPanCancel: () => _onSeekEnd(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: ColoredBox(
                color: Colors.black,
                child: _ready && _controller != null
                    ? Transform.scale(
                        scale: 0.82,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    : const Center(child: MurkotLoader(size: 28)),
              ),
            ),
            if (_ready)
              CustomPaint(
                painter: _CircleProgressPainter(
                  progress: _progress,
                  active: _seeking || !_playing,
                ),
              ),
            if (_ready && !_playing)
              const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white70,
                  size: 44,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  _CircleProgressPainter({required this.progress, this.active = false});

  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = active ? 4.0 : 3.0;
    final inset = stroke + 1;
    final rect =
        Offset(inset, inset) & Size(size.width - inset * 2, size.height - inset * 2);
    final bg = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
    // Scrub knob on the ring.
    final a = -math.pi / 2 + math.pi * 2 * progress.clamp(0.0, 1.0);
    final cx = size.width / 2 + math.cos(a) * (size.width / 2 - inset);
    final cy = size.height / 2 + math.sin(a) * (size.height / 2 - inset);
    canvas.drawCircle(
      Offset(cx, cy),
      active ? 7 : 5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}
