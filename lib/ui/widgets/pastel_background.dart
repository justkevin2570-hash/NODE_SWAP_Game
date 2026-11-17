import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// 천천히 떠다니는 파스텔 블롭 배경. [fever] 면 빠르게 무지개빛으로 순환한다.
class PastelBackground extends StatefulWidget {
  const PastelBackground({
    super.key,
    required this.child,
    this.fever = false,
    this.tint,
  });

  final Widget child;
  final bool fever;
  final Color? tint;

  @override
  State<PastelBackground> createState() => _PastelBackgroundState();
}

class _PastelBackgroundState extends State<PastelBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  final _blobs = List.generate(7, (i) => _Blob(Random(i * 31 + 7)));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.fever
                  ? const [Color(0xFFFFF0F6), Color(0xFFFFF6E6), Color(0xFFEFFAF5)]
                  : [
                      Palette.cream,
                      Color.lerp(Palette.blush, widget.tint ?? Palette.blush, 0.25)!,
                      Palette.mist,
                    ],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              painter: _BlobPainter(_blobs, _ctrl.value, widget.fever, widget.tint),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Blob {
  _Blob(Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        radius = 0.18 + r.nextDouble() * 0.22,
        speed = 1 + r.nextInt(3).toDouble(),
        phase = r.nextDouble() * pi * 2,
        color = Palette.blobs[r.nextInt(Palette.blobs.length)];

  final double x, y, radius, speed, phase;
  final Color color;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.blobs, this.t, this.fever, this.tint);

  final List<_Blob> blobs;
  final double t;
  final bool fever;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final base = min(size.width, size.height);
    final speedMul = fever ? 6.0 : 1.0;
    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final a = t * pi * 2 * b.speed * speedMul + b.phase;
      final cx = (b.x + 0.08 * sin(a)) * size.width;
      final cy = (b.y + 0.06 * cos(a * 0.8)) * size.height;
      final r = b.radius * base * (1 + 0.08 * sin(a * 1.3));
      Color c = b.color;
      if (fever) {
        final k = (t * 30 + i / blobs.length) % 1.0;
        final idx = (k * Palette.fever.length).floor();
        c = Color.lerp(Palette.fever[idx], Palette.fever[(idx + 1) % Palette.fever.length],
            k * Palette.fever.length - idx)!;
      } else if (tint != null && i.isEven) {
        c = Color.lerp(c, tint, 0.5)!;
      }
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          c.withValues(alpha: fever ? 0.45 : 0.55),
          c.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => true;
}
