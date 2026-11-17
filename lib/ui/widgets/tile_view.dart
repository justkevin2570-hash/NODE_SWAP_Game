import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// 보드의 타일 한 칸. 값 1 은 대칭 색의 말랑한 캔디, 값 0 은 하얀 구름 타일.
class TileView extends StatefulWidget {
  const TileView({
    super.key,
    required this.value,
    required this.size,
    required this.light,
    required this.deep,
    this.selected = false,
    this.hinted = false,
    this.dimmed = false,
    this.entranceDelay,
    this.bumpToken = 0,
    this.pulseToken = 0,
    this.nudgeToken = 0,
    this.celebrateToken = 0,
    this.celebrateDelay = Duration.zero,
  });

  final int value;
  final double size;
  final Color light;
  final Color deep;
  final bool selected;
  final bool hinted;
  final bool dimmed;

  /// null 이 아니면 처음 나타날 때 톡 튀어나온다.
  final Duration? entranceDelay;

  /// 값이 바뀔 때마다 해당 연출을 한 번 재생한다.
  final int bumpToken;
  final int pulseToken;
  final int nudgeToken;
  final int celebrateToken;
  final Duration celebrateDelay;

  @override
  State<TileView> createState() => _TileViewState();
}

class _TileViewState extends State<TileView> with TickerProviderStateMixin {
  late final _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final _nudge = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late final _celebrate = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  late final _hint = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    final d = widget.entranceDelay;
    if (d == null) {
      _entrance.value = 1;
    } else {
      Future.delayed(d, () {
        if (mounted) _entrance.forward();
      });
    }
    if (widget.hinted) _hint.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(TileView old) {
    super.didUpdateWidget(old);
    if (widget.bumpToken != old.bumpToken) _bump.forward(from: 0);
    if (widget.pulseToken != old.pulseToken) _pulse.forward(from: 0);
    if (widget.nudgeToken != old.nudgeToken) _nudge.forward(from: 0);
    if (widget.celebrateToken != old.celebrateToken) {
      Future.delayed(widget.celebrateDelay, () {
        if (mounted) _celebrate.forward(from: 0);
      });
    }
    if (widget.hinted && !_hint.isAnimating) {
      _hint.repeat(reverse: true);
    } else if (!widget.hinted && _hint.isAnimating) {
      _hint
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    for (final c in [_entrance, _bump, _pulse, _nudge, _celebrate, _hint]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _bump, _pulse, _nudge, _celebrate, _hint]),
      builder: (context, _) {
        final e = Curves.elasticOut.transform(_entrance.value.clamp(0.0, 1.0));
        // 스왑 직후 말랑하게 찌그러졌다 돌아오는 효과
        final b = sin(_bump.value * pi);
        final sx = 1 + 0.14 * b;
        final sy = 1 - 0.12 * b;
        // 대칭 쌍이 맞았을 때 톡 커지는 효과
        final p = sin(_pulse.value * pi) * 0.12;
        // 잘못된 조작일 때 좌우로 흔들기
        final n = sin(_nudge.value * pi * 4) * (1 - _nudge.value) * widget.size * 0.08;
        // 클리어 웨이브: 위로 튀고 반 바퀴 돈다
        final c = _celebrate.value;
        final jump = -sin(c * pi) * widget.size * 0.35;
        final spin = Curves.easeInOutBack.transform(c) * pi;
        final selectedLift = widget.selected ? 1.1 : 1.0;
        final hintScale = 1 + _hint.value * 0.06;

        return Transform.translate(
          offset: Offset(n, jump),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(spin)
              ..scaleByDouble(e * sx * selectedLift * hintScale + p, e * sy * selectedLift * hintScale + p, 1, 1),
            child: _face(c),
          ),
        );
      },
    );
  }

  Widget _face(double celebrate) {
    final s = widget.size;
    final r = BorderRadius.circular(s * 0.3);
    final on = widget.value == 1;
    final flash = sin(celebrate * pi);
    final light = Color.lerp(widget.light, Colors.white, flash * 0.5)!;
    final deep = Color.lerp(widget.deep, widget.light, flash * 0.5)!;

    final ringColor = widget.hinted
        ? Color.lerp(Palette.butterDeep, Colors.white, _hint.value * 0.4)!
        : Palette.butterDeep;
    final showRing = widget.selected || widget.hinted;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.dimmed ? 0.45 : 1,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: on
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(light, Colors.white, 0.25)!, deep],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF6F2FF)],
                ),
          border: showRing
              ? Border.all(color: ringColor, width: s * 0.07)
              : on
                  ? null
                  : Border.all(color: Palette.lavender.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: (on ? widget.deep : Palette.lavenderDeep).withValues(alpha: on ? 0.42 : 0.16),
              blurRadius: widget.selected ? 18 : 8,
              offset: Offset(0, widget.selected ? 8 : 4),
            ),
            if (showRing)
              BoxShadow(
                color: Palette.butterDeep.withValues(alpha: 0.45 + _hint.value * 0.3),
                blurRadius: 18,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          children: [
            // 광택
            Positioned(
              left: s * 0.14,
              top: s * 0.1,
              width: s * 0.42,
              height: s * 0.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: on ? 0.55 : 0.9),
                  borderRadius: BorderRadius.circular(s),
                ),
              ),
            ),
            if (on)
              Positioned(
                right: s * 0.18,
                bottom: s * 0.18,
                width: s * 0.14,
                height: s * 0.14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
