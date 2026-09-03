import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'unlumen/murkot_fx.dart';

/// Which circle is currently expanded (with sound). Others stay muted & compact.
final ValueNotifier<String?> circleExpandedUrl = ValueNotifier<String?>(null);

/// Telegram-style circular video note.
class CircleVideoPlayer extends StatefulWidget {
  const CircleVideoPlayer({
    super.key,
    required this.url,
    this.size = 200,
    this.expandedSize = 280,
  });

  final String url;
  final double size;
  final double expandedSize;

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

  bool get _expanded => circleExpandedUrl.value == widget.url;

  @override
  void initState() {
    super.initState();
    circleExpandedUrl.addListener(_onExpandedChanged);
    _boot(widget.url);
  }

  void _onExpandedChanged() {
    if (!mounted) return;
    _syncMode();
    setState(() {});
  }

  Future<void> _syncMode() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (_expanded) {
      await c.setVolume(1);
      await c.setLooping(false);
    } else {
      // Not selected → silent looping preview.
      await c.setVolume(0);
      await c.setLooping(true);
      if (!c.value.isPlaying) {
        await c.play();
        if (mounted) setState(() => _playing = true);
      }
    }
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
      // Collapsed: muted preview, no auto-expand. Wait for first frame.
      await c.setVolume(0);
      await c.setLooping(true);
      await c.seekTo(Duration.zero);
      // Do NOT autoplay on chat open — show first frame + play icon.
      await c.pause();
      if (!mounted || _controller != c) return;
      setState(() {
        _ready = true;
        _playing = false;
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

    if (_expanded && dur > 0 && pos >= dur - 80) {
      if (c.value.isPlaying) c.pause();
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
      if (circleExpandedUrl.value == oldWidget.url) {
        circleExpandedUrl.value = null;
      }
      _boot(widget.url);
    }
  }

  @override
  void dispose() {
    circleExpandedUrl.removeListener(_onExpandedChanged);
    if (circleExpandedUrl.value == widget.url) {
      circleExpandedUrl.value = null;
    }
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _expandAndPlay() async {
    final c = _controller;
    if (c == null || !_ready) return;
    circleExpandedUrl.value = widget.url;
    await c.setVolume(1);
    await c.setLooping(false);
    await c.seekTo(Duration.zero);
    await c.play();
    if (mounted) {
      setState(() {
        _progress = 0;
        _playing = true;
      });
    }
  }

  Future<void> _collapseMuted() async {
    final c = _controller;
    if (circleExpandedUrl.value == widget.url) {
      circleExpandedUrl.value = null;
    }
    if (c == null || !_ready) return;
    await c.setVolume(0);
    await c.setLooping(true);
    await c.seekTo(Duration.zero);
    await c.play();
    if (mounted) {
      setState(() {
        _playing = true;
        _progress = 0;
      });
    }
  }

  Future<void> _toggleExpandedPlay() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (!_expanded) {
      await _expandAndPlay();
      return;
    }
    if (c.value.isPlaying) {
      await c.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      if (_progress >= 0.98) {
        await c.seekTo(Duration.zero);
        if (mounted) setState(() => _progress = 0);
      }
      await c.setVolume(1);
      await c.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  Future<void> _seekFraction(double fraction) async {
    final c = _controller;
    if (c == null || !_ready || !_expanded) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    final ms = (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await c.seekTo(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() => _progress = fraction.clamp(0.0, 1.0));
  }

  double? _fractionFromLocal(Offset local, double size) {
    if (!_expanded) return null;
    final center = Offset(size / 2, size / 2);
    final v = local - center;
    final dist = v.distance;
    final outer = size / 2;
    if (dist < outer * 0.62 || dist > outer * 1.08) return null;
    var angle = math.atan2(v.dy, v.dx);
    var frac = (angle + math.pi / 2) / (math.pi * 2);
    if (frac < 0) frac += 1;
    return frac.clamp(0.0, 1.0);
  }

  /// Classic cover fill — no letterboxing / black bars inside the circle.
  Widget _videoFill() {
    final c = _controller!;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _expanded ? widget.expandedSize : widget.size;
    if (_failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final frac = _fractionFromLocal(d.localPosition, size);
          if (frac != null) {
            _seeking = true;
            _seekFraction(frac).whenComplete(() => _seeking = false);
            return;
          }
          _toggleExpandedPlay();
        },
        onLongPress: _expanded ? _collapseMuted : null,
        onPanStart: (d) {
          final frac = _fractionFromLocal(d.localPosition, size);
          if (frac == null) return;
          _seeking = true;
          _seekFraction(frac);
        },
        onPanUpdate: (d) {
          if (!_seeking) return;
          final frac = _fractionFromLocal(d.localPosition, size);
          if (frac != null) _seekFraction(frac);
        },
        onPanEnd: (_) => _seeking = false,
        onPanCancel: () => _seeking = false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: ColoredBox(
                color: Colors.black,
                child: _ready && _controller != null
                    ? _videoFill()
                    : const Center(child: MurkotLoader(size: 28)),
              ),
            ),
            if (_ready && _expanded)
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
