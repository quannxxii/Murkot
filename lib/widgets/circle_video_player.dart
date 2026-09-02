import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'unlumen/murkot_fx.dart';

/// Telegram-style circular video note.
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
  double _progress = 0;
  double _stretch = 1;

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
      await c.setLooping(true);
      await c.seekTo(Duration.zero);
      await c.play();
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
    if (c == null || !_ready || !mounted) return;
    final dur = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    final nextProgress = dur <= 0 ? 0.0 : (pos / dur).clamp(0.0, 1.0);
    final nextPlaying = c.value.isPlaying;
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
    } else {
      if (_progress >= 0.98) await c.seekTo(Duration.zero);
      await c.play();
    }
  }

  Future<void> _seekFraction(double fraction) async {
    final c = _controller;
    if (c == null || !_ready) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    final ms = (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round();
    await c.seekTo(Duration(milliseconds: ms));
    if (!c.value.isPlaying) await c.play();
  }

  bool _onScroll(ScrollNotification n) {
    // Pull-down rubber-band: grow circle + video together.
    if (n is OverscrollNotification && n.overscroll < 0) {
      final next = (1 + (-n.overscroll) / 180).clamp(1.0, 1.35);
      if ((next - _stretch).abs() > 0.01) setState(() => _stretch = next);
    } else if (n is ScrollEndNotification ||
        (n is ScrollUpdateNotification && n.metrics.pixels >= 0)) {
      if (_stretch != 1) setState(() => _stretch = 1);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size * _stretch;
    if (_failed) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          onTap: _toggle,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(
                child: ColoredBox(
                  color: Colors.black,
                  child: _ready && _controller != null
                      ? Transform.scale(
                          // Slightly zoomed-out vs default cover → wider FOV.
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
                IgnorePointer(
                  child: CustomPaint(
                    painter: _CircleProgressPainter(progress: _progress),
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
              if (_ready)
                Positioned(
                  left: size * 0.2,
                  right: size * 0.2,
                  bottom: 8,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final local = box.globalToLocal(d.globalPosition);
                      final left = size * 0.2;
                      final width = size * 0.6;
                      final fraction =
                          ((local.dx - left) / width).clamp(0.0, 1.0);
                      _seekFraction(fraction);
                    },
                    onTapDown: (d) {
                      final width = size * 0.6;
                      final fraction =
                          (d.localPosition.dx / width).clamp(0.0, 1.0);
                      _seekFraction(fraction);
                    },
                    child: SizedBox(
                      height: 16,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: _progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  _CircleProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 2.5;
    final rect =
        Offset(stroke, stroke) & Size(size.width - stroke * 2, size.height - stroke * 2);
    final bg = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -1.5708, 6.2832, false, bg);
    canvas.drawArc(rect, -1.5708, 6.2832 * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
