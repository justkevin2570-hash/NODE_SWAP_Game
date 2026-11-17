import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/palette.dart';

enum ParticleShape { circle, star, heart, ring }

class _Particle {
  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.color,
    required this.shape,
    required this.spin,
    required this.gravity,
  }) : maxLife = life;

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final ParticleShape shape;
  final double spin;
  final double gravity;
  double angle = 0;
}

/// 화면 위에 파티클을 뿌리는 오버레이. GlobalKey 로 [ParticleFieldState] 에 접근한다.
class ParticleField extends StatefulWidget {
  const ParticleField({super.key, required this.child});

  final Widget child;

  @override
  State<ParticleField> createState() => ParticleFieldState();
}

class ParticleFieldState extends State<ParticleField> with SingleTickerProviderStateMixin {
  final _particles = <_Particle>[];
  final _rng = Random();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  final _repaint = ValueNotifier<int>(0);

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  /// 사방으로 터지는 폭죽.
  void burst(
    Offset globalPos, {
    int count = 28,
    List<Color>? colors,
    double speed = 420,
    double size = 9,
    double life = 0.9,
    double gravity = 600,
    List<ParticleShape> shapes = const [ParticleShape.circle, ParticleShape.star],
  }) {
    final p = _toLocal(globalPos);
    final palette = colors ?? Palette.fever;
    for (int i = 0; i < count; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final v = speed * (0.35 + _rng.nextDouble() * 0.65);
      _particles.add(_Particle(
        pos: p,
        vel: Offset(cos(a) * v, sin(a) * v - speed * 0.25),
        life: life * (0.6 + _rng.nextDouble() * 0.5),
        size: size * (0.6 + _rng.nextDouble() * 0.8),
        color: palette[_rng.nextInt(palette.length)],
        shape: shapes[_rng.nextInt(shapes.length)],
        spin: (_rng.nextDouble() - 0.5) * 12,
        gravity: gravity,
      ));
    }
    _start();
  }

  /// 칸 하나 위에서 반짝이는 작은 별.
  void sparkle(Offset globalPos, Color color, {int count = 7}) {
    burst(
      globalPos,
      count: count,
      colors: [color, Colors.white, Palette.butterDeep],
      speed: 160,
      size: 7,
      life: 0.55,
      gravity: 0,
      shapes: const [ParticleShape.star, ParticleShape.circle],
    );
  }

  /// 위에서 쏟아지는 꽃가루 (신기록 등).
  void confetti({int count = 90}) {
    final box = context.findRenderObject() as RenderBox?;
    final w = box?.size.width ?? 400;
    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(
        pos: Offset(_rng.nextDouble() * w, -20 - _rng.nextDouble() * 200),
        vel: Offset((_rng.nextDouble() - 0.5) * 120, 120 + _rng.nextDouble() * 200),
        life: 3.2 + _rng.nextDouble(),
        size: 7 + _rng.nextDouble() * 7,
        color: Palette.fever[_rng.nextInt(Palette.fever.length)],
        shape: ParticleShape.values[_rng.nextInt(3)],
        spin: (_rng.nextDouble() - 0.5) * 8,
        gravity: 60,
      ));
    }
    _start();
  }

  /// 퍼져 나가는 원형 파동.
  void ring(Offset globalPos, Color color, {double size = 60}) {
    _particles.add(_Particle(
      pos: _toLocal(globalPos),
      vel: Offset.zero,
      life: 0.6,
      size: size,
      color: color,
      shape: ParticleShape.ring,
      spin: 0,
      gravity: 0,
    ));
    _start();
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    for (final p in _particles) {
      p.vel = Offset(p.vel.dx * (1 - 1.6 * dt), p.vel.dy * (1 - 1.6 * dt) + p.gravity * dt);
      p.pos += p.vel * dt;
      p.angle += p.spin * dt;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    if (_particles.isEmpty) _ticker.stop();
    _repaint.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _ParticlePainter(_particles, _repaint)),
          ),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, Listenable repaint) : super(repaint: repaint);

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      if (p.shape == ParticleShape.ring) {
        final k = 1 - t;
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * t
          ..color = p.color.withValues(alpha: t * 0.8);
        canvas.drawCircle(p.pos, p.size * (0.3 + k * 1.2), paint);
        continue;
      }
      paint
        ..style = PaintingStyle.fill
        ..color = p.color.withValues(alpha: min(1.0, t * 1.6));
      final s = p.size * (0.4 + 0.6 * t);
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      switch (p.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, s / 2, paint);
        case ParticleShape.star:
          canvas.drawPath(_star(s), paint);
        case ParticleShape.heart:
          canvas.drawPath(_heart(s), paint);
        case ParticleShape.ring:
          break;
      }
      canvas.restore();
    }
  }

  static Path _star(double s) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final r = i.isEven ? s * 0.6 : s * 0.22;
      final a = i * pi / 4 - pi / 2;
      final o = Offset(cos(a) * r, sin(a) * r);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  static Path _heart(double s) {
    final h = s * 0.55;
    return Path()
      ..moveTo(0, h * 0.9)
      ..cubicTo(-h * 1.6, -h * 0.2, -h * 0.6, -h * 1.3, 0, -h * 0.45)
      ..cubicTo(h * 0.6, -h * 1.3, h * 1.6, -h * 0.2, 0, h * 0.9)
      ..close();
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => false;
}
