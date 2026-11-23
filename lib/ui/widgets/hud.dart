import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../game/logic/symmetry.dart';
import 'math_text.dart';

/// 남은 시간 막대. 시간이 적으면 붉게 맥박친다.
class TimerBar extends StatefulWidget {
  const TimerBar({
    super.key,
    required this.fraction,
    required this.remainingMs,
    this.fever = false,
    this.feverFraction = 0,
  });

  final double fraction;
  final int remainingMs;
  final bool fever;
  final double feverFraction;

  @override
  State<TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<TimerBar> with SingleTickerProviderStateMixin {
  // 맥박은 시간이 얼마 안 남았을 때만 돌린다 (평소엔 멈춰 있어 화면을 다시 그리지 않음).
  late final _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  bool get _critical => widget.remainingMs <= 10000 && !widget.fever;

  @override
  void initState() {
    super.initState();
    _syncBeat();
  }

  @override
  void didUpdateWidget(TimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBeat();
  }

  void _syncBeat() {
    if (_critical && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if (!_critical && _beat.isAnimating) {
      _beat
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final critical = widget.remainingMs <= 10000 && !widget.fever;
    final secs = (widget.remainingMs / 1000).ceil();
    return AnimatedBuilder(
      animation: _beat,
      builder: (context, _) {
        final pulse = critical ? _beat.value : 0.0;
        final colors = widget.fever
            ? Palette.fever
            : critical
                ? [Palette.danger, Palette.peachDeep]
                : widget.fraction < 0.4
                    ? [Palette.peachDeep, Palette.butterDeep]
                    : [Palette.mintDeep, Palette.skyDeep];
        return Row(
          children: [
            Transform.scale(
              scale: 1 + pulse * 0.15,
              child: Icon(
                widget.fever ? Icons.local_fire_department_rounded : Icons.timer_rounded,
                color: critical ? Palette.danger : Palette.inkSoft,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (critical ? Palette.danger : Palette.lavenderDeep)
                          .withValues(alpha: 0.15 + pulse * 0.35),
                      blurRadius: 8 + pulse * 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final f = widget.fever ? widget.feverFraction : widget.fraction;
                    return Align(
                      alignment: Alignment.centerLeft,
                      // 0.1초마다 갱신되므로 따로 애니메이션을 주지 않는다 (계속 다시 그리는 것 방지)
                      child: Container(
                        width: max(12.0, c.maxWidth * f),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text(
                widget.fever ? 'FEVER' : '$secs',
                textAlign: TextAlign.right,
                style: TextStyles.number.copyWith(
                  fontSize: widget.fever ? 16 : 24 + pulse * 4,
                  color: critical ? Palette.danger : Palette.ink,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 남은 이동 수 구슬.
/// 남은 이동 표시: 보드 타일을 줄인 작은 사각형들.
/// 남은 이동은 테마색으로 채우고, 쓴 이동은 테두리만 남긴다 (크기는 그대로라 줄이 흔들리지 않음).
class MovesPips extends StatelessWidget {
  const MovesPips({
    super.key,
    required this.used,
    required this.max,
    required this.color,
    this.light,
  });

  final int used;
  final int max;

  /// 테마의 진한 색.
  final Color color;

  /// 테마의 밝은 색 (없으면 진한 색에서 만든다).
  final Color? light;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < max; i++)
          MoveTile(filled: i < max - used, deep: color, light: light ?? Color.lerp(color, Colors.white, 0.45)!),
      ],
    );
  }
}

/// 남은 이동 한 칸.
class MoveTile extends StatelessWidget {
  const MoveTile({super.key, required this.filled, required this.deep, required this.light, this.size = 22});

  final bool filled;
  final Color deep;
  final Color light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: filled
              ? [Color.lerp(light, Colors.white, 0.25)!, deep]
              : [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0)],
        ),
        border: Border.all(
          color: filled ? Colors.white.withValues(alpha: 0.9) : deep.withValues(alpha: 0.55),
          width: filled ? 1.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: deep.withValues(alpha: filled ? 0.35 : 0),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 작은 광택 (채워진 칸에만)
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: filled ? 1 : 0,
        child: Align(
          alignment: const Alignment(-0.35, -0.55),
          child: Container(
            width: size * 0.42,
            height: size * 0.18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
        ),
      ),
    );
  }
}

/// 숫자가 촤르륵 올라가는 점수 표시.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    this.style = TextStyles.number,
    this.duration = const Duration(milliseconds: 500),
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatInt(v.round()), style: style),
    );
  }

  static String formatInt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// 목표 대칭 표시 칩.
class SymmetryBadge extends StatelessWidget {
  const SymmetryBadge({super.key, required this.type, this.compact = false});

  final SymmetryType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (light, deep) = Palette.forSymmetry(type);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: Container(
        key: ValueKey(type),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 5 : 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(light, Colors.white, 0.3)!, light]),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: softShadow(deep, blur: 10, y: 4, opacity: 0.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymmetryIcon(type: type, color: deep, size: compact ? 16 : 20),
            const SizedBox(width: 6),
            if (type.formula == null)
              Text(type.label, style: TextStyle(fontFamily: kFont, fontSize: compact ? 14 : 17, color: Palette.ink))
            else
              // 식 부분은 테마 색으로 조금 크게, "대칭"은 다른 대칭 칩과 같은 모양으로
              Text.rich(
                TextSpan(children: [
                  // 식 부분은 교과서 수식처럼 (세리프 이탤릭 변수, 수학 빼기 기호)
                  ...mathSpans(
                    type.formula!,
                    fontSize: compact ? 18 : 22,
                    color: Color.lerp(deep, Palette.ink, 0.6)!,
                  ),
                  TextSpan(text: tr(' 대칭')),
                ]),
                style: TextStyle(fontFamily: kFont, fontSize: compact ? 14 : 17, color: Palette.ink, height: 1.1),
              ),
          ],
        ),
      ),
    );
  }
}

class SymmetryIcon extends StatelessWidget {
  const SymmetryIcon({super.key, required this.type, required this.color, this.size = 20});

  final SymmetryType type;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SymIconPainter(type, color));
}

class _SymIconPainter extends CustomPainter {
  _SymIconPainter(this.type, this.color);
  final SymmetryType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = Palette.ink.withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final u = s.width / 10;
    RRect sq(double x, double y) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x * u, y * u, 3 * u, 3 * u), Radius.circular(u));
    switch (type) {
      case SymmetryType.horizontal:
        canvas.drawRRect(sq(0.5, 3.5), fill);
        canvas.drawRRect(sq(6.5, 3.5), fill);
        canvas.drawLine(Offset(5 * u, 0), Offset(5 * u, 10 * u), line);
      case SymmetryType.vertical:
        canvas.drawRRect(sq(3.5, 0.5), fill);
        canvas.drawRRect(sq(3.5, 6.5), fill);
        canvas.drawLine(Offset(0, 5 * u), Offset(10 * u, 5 * u), line);
      case SymmetryType.point:
        canvas.drawRRect(sq(0.5, 0.5), fill);
        canvas.drawRRect(sq(6.5, 6.5), fill);
        canvas.drawCircle(Offset(5 * u, 5 * u), 1.3 * u, Paint()..color = Palette.ink.withValues(alpha: 0.6));
      case SymmetryType.diagonalUp: // ↗ 선을 사이에 두고 왼쪽 위 ↔ 오른쪽 아래
        canvas.drawRRect(sq(0.5, 0.5), fill);
        canvas.drawRRect(sq(6.5, 6.5), fill);
        canvas.drawLine(Offset(0, 10 * u), Offset(10 * u, 0), line);
      case SymmetryType.diagonalDown: // ↘ 선을 사이에 두고 오른쪽 위 ↔ 왼쪽 아래
        canvas.drawRRect(sq(6.5, 0.5), fill);
        canvas.drawRRect(sq(0.5, 6.5), fill);
        canvas.drawLine(Offset.zero, Offset(10 * u, 10 * u), line);
    }
  }

  @override
  bool shouldRepaint(_SymIconPainter old) => old.type != type || old.color != color;
}
