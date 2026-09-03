import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/brand_theme.dart';
import '../models/conversation.dart';
import '../models/plus_cosmetics.dart';
import '../utils/helpers.dart';

class AvatarDisplay extends StatelessWidget {
  const AvatarDisplay({
    super.key,
    this.avatarPath,
    this.avatarEmoji,
    required this.name,
    this.radius = 26,
    this.fontSize,
    this.frame = AvatarFrameId.none,
    this.showPlusBadge = false,
  });

  final String? avatarPath;
  final String? avatarEmoji;
  final String name;
  final double radius;
  final double? fontSize;
  final AvatarFrameId frame;
  final bool showPlusBadge;

  bool get _looksLikeGif {
    final p = avatarPath?.toLowerCase() ?? '';
    return p.contains('.gif') || p.contains('image/gif');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = avatarPath;
    final isNetwork =
        path != null && (path.startsWith('http://') || path.startsWith('https://'));
    final hasFile = localPathExists(path);
    final size = radius * 2;
    final ringPad = frame == AvatarFrameId.none ? 0.0 : math.max(4.0, radius * 0.12);
    final total = size + ringPad * 2;

    Widget? imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: _looksLikeGif ? FilterQuality.low : FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (hasFile && path != null) {
      imageWidget = Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    final face = imageWidget != null
        ? SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: Container(
                  color: theme.colorScheme.primaryContainer,
                  child: imageWidget,
                ),
              ),
            ),
          )
        : SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: Container(
                color: theme.colorScheme.primaryContainer,
                child: Center(
                  child: Text(
                    avatarEmoji ??
                        (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                    style: TextStyle(
                      fontSize: fontSize ?? radius * 0.85,
                      fontWeight: FontWeight.bold,
                      color: avatarEmoji != null
                          ? null
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          );

    Widget body = face;
    if (frame != AvatarFrameId.none) {
      // Frame drawn ON TOP of the avatar so decorations stay visible.
      body = SizedBox(
        width: total,
        height: total,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            face,
            IgnorePointer(
              child: _AvatarFrameRing(frame: frame, size: total),
            ),
          ],
        ),
      );
    }

    // Always force a perfect circle (never oval under tight layout).
    body = SizedBox(
      width: total,
      height: total,
      child: AspectRatio(
        aspectRatio: 1,
        child: body,
      ),
    );

    if (!showPlusBadge) return body;

    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: MurkotColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
              child: const Icon(Icons.star, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFrameRing extends StatefulWidget {
  const _AvatarFrameRing({required this.frame, required this.size});

  final AvatarFrameId frame;
  final double size;

  @override
  State<_AvatarFrameRing> createState() => _AvatarFrameRingState();
}

class _AvatarFrameRingState extends State<_AvatarFrameRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _FramePainter(
            frame: widget.frame,
            t: _ctrl.value,
          ),
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.frame, required this.t});

  final AvatarFrameId frame;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    switch (frame) {
      case AvatarFrameId.none:
        return;
      case AvatarFrameId.stars:
        _paintStars(canvas, c, r);
      case AvatarFrameId.sparkle:
        _paintSparkle(canvas, c, r);
      case AvatarFrameId.wave:
        _paintWave(canvas, c, r);
      case AvatarFrameId.dots:
        _paintDots(canvas, c, r);
      case AvatarFrameId.citrus:
        _paintCitrus(canvas, c, r);
      case AvatarFrameId.drops:
        _paintDrops(canvas, c, r);
    }
  }

  void _paintStars(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = MurkotColors.yellow;
    for (var i = 0; i < 8; i++) {
      final a = t * math.pi * 2 + i * (math.pi * 2 / 8);
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      _star(canvas, p, 6.5 + (i.isEven ? 2.2 : 0), paint);
    }
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = MurkotColors.orange.withValues(alpha: 0.9),
    );
  }

  void _paintSparkle(Canvas canvas, Offset c, double r) {
    final shader = SweepGradient(
      colors: [
        MurkotColors.yellow,
        MurkotColors.orange,
        Colors.white,
        MurkotColors.deepOrange,
        MurkotColors.yellow,
      ],
      transform: GradientRotation(t * math.pi * 2),
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0,
    );
  }

  void _paintWave(Canvas canvas, Offset c, double r) {
    final path = Path();
    const waves = 18;
    for (var i = 0; i <= waves; i++) {
      final a = i / waves * math.pi * 2;
      final wobble = math.sin(a * 4 + t * math.pi * 2) * 3.2;
      final p = Offset(
        c.dx + math.cos(a) * (r + wobble),
        c.dy + math.sin(a) * (r + wobble),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..color = const Color(0xFF3B82F6),
    );
  }

  void _paintDots(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = MurkotColors.deepOrange;
    for (var i = 0; i < 20; i++) {
      final a = i / 20 * math.pi * 2 + t * math.pi * 2 * 0.15;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawCircle(p, i.isEven ? 4.2 : 2.8, paint);
    }
  }

  void _paintCitrus(Canvas canvas, Offset c, double r) {
    // Rotating orange wedges (rind) around the avatar.
    const slices = 8;
    final rot = t * math.pi * 2;
    for (var i = 0; i < slices; i++) {
      final a0 = rot + i * (math.pi * 2 / slices);
      final a1 = a0 + math.pi * 2 / slices * 0.78;
      final rind = Path()
        ..moveTo(
          c.dx + math.cos(a0) * (r - 7),
          c.dy + math.sin(a0) * (r - 7),
        )
        ..lineTo(
          c.dx + math.cos(a0) * (r + 2),
          c.dy + math.sin(a0) * (r + 2),
        )
        ..arcToPoint(
          Offset(
            c.dx + math.cos(a1) * (r + 2),
            c.dy + math.sin(a1) * (r + 2),
          ),
          radius: Radius.circular(r + 2),
          largeArc: false,
        )
        ..lineTo(
          c.dx + math.cos(a1) * (r - 7),
          c.dy + math.sin(a1) * (r - 7),
        )
        ..arcToPoint(
          Offset(
            c.dx + math.cos(a0) * (r - 7),
            c.dy + math.sin(a0) * (r - 7),
          ),
          radius: Radius.circular(r - 7),
          clockwise: false,
        )
        ..close();
      canvas.drawPath(
        rind,
        Paint()
          ..color = (i.isEven ? MurkotColors.orange : MurkotColors.yellow)
              .withValues(alpha: 0.95),
      );
      final mid = (a0 + a1) / 2;
      canvas.drawLine(
        Offset(c.dx + math.cos(mid) * (r - 6), c.dy + math.sin(mid) * (r - 6)),
        Offset(c.dx + math.cos(mid) * (r + 1), c.dy + math.sin(mid) * (r + 1)),
        Paint()
          ..color = MurkotColors.deepOrange.withValues(alpha: 0.55)
          ..strokeWidth = 1.8,
      );
    }
  }

  void _paintDrops(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75),
    );
    final paint = Paint()..color = const Color(0xFF0EA5E9);
    for (var i = 0; i < 10; i++) {
      final a = t * math.pi * 2 + i * (math.pi * 2 / 10);
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      final path = Path()
        ..moveTo(p.dx, p.dy - 7)
        ..quadraticBezierTo(p.dx + 5.5, p.dy, p.dx, p.dy + 7)
        ..quadraticBezierTo(p.dx - 5.5, p.dy, p.dx, p.dy - 7);
      canvas.drawPath(path, paint);
    }
  }

  void _star(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * (math.pi * 2 / 5);
      final outer = Offset(c.dx + math.cos(a) * s, c.dy + math.sin(a) * s);
      final ia = a + math.pi / 5;
      final inner =
          Offset(c.dx + math.cos(ia) * s * 0.4, c.dy + math.sin(ia) * s * 0.4);
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.frame != frame;
}

String conversationAvatarEmoji(Conversation conversation) {
  return conversation.avatarEmoji ?? pickRandomEmoji(conversation.name.hashCode);
}

String pickRandomEmoji([int? seed]) {
  const emojis = [
    '😀', '🦊', '🐱', '🐶', '🌟', '🎮', '🎨', '🔥',
    '💎', '🚀', '🌈', '🎭', '🎵', '⚡', '🍀', '🦄',
  ];
  if (seed != null) return emojis[seed.abs() % emojis.length];
  return emojis[DateTime.now().millisecondsSinceEpoch % emojis.length];
}
