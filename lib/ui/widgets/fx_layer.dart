import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/theme.dart';

/// 점수, 콤보, 배너 같은 떠오르는 글자 연출 레이어.
class FxLayer extends StatefulWidget {
  const FxLayer({super.key, required this.child});

  final Widget child;

  @override
  State<FxLayer> createState() => FxLayerState();
}

class FxLayerState extends State<FxLayer> {
  final _items = <_FxItem>[];
  int _seq = 0;

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  /// [global] 위치에서 위로 떠오르는 작은 글자.
  void floatText(
    String text,
    Offset global, {
    Color color = Palette.ink,
    double size = 26,
    Duration duration = const Duration(milliseconds: 900),
    double rise = 70,
  }) {
    _add(_FxItem(
      id: _seq++,
      kind: _FxKind.float,
      text: text,
      pos: _toLocal(global),
      color: color,
      size: size,
      duration: duration,
      rise: rise,
    ));
  }

  /// 화면 가운데에 크게 튀어나오는 배너.
  void banner(
    String text, {
    String? sub,
    Color color = Palette.pinkDeep,
    double size = 56,
    Duration duration = const Duration(milliseconds: 1100),
    double dy = 0,
  }) {
    _add(_FxItem(
      id: _seq++,
      kind: _FxKind.banner,
      text: text,
      sub: sub,
      pos: Offset(0, dy),
      color: color,
      size: size,
      duration: duration,
    ));
  }

  void _add(_FxItem item) {
    setState(() => _items.add(item));
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final item in _items)
                _FxWidget(key: ValueKey(item.id), item: item, onDone: () => _remove(item.id)),
            ],
          ),
        ),
      ],
    );
  }
}

enum _FxKind { float, banner }

class _FxItem {
  _FxItem({
    required this.id,
    required this.kind,
    required this.text,
    required this.pos,
    required this.color,
    required this.size,
    required this.duration,
    this.sub,
    this.rise = 70,
  });

  final int id;
  final _FxKind kind;
  final String text;
  final String? sub;
  final Offset pos;
  final Color color;
  final double size;
  final Duration duration;
  final double rise;
}

class _FxWidget extends StatefulWidget {
  const _FxWidget({super.key, required this.item, required this.onDone});

  final _FxItem item;
  final VoidCallback onDone;

  @override
  State<_FxWidget> createState() => _FxWidgetState();
}

class _FxWidgetState extends State<_FxWidget> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.item.duration)
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  TextStyle _style(double size, Color color) => TextStyle(
        fontFamily: kFont,
        fontSize: size,
        color: color,
        height: 1.0,
        shadows: [
          const Shadow(color: Colors.white, blurRadius: 0, offset: Offset(0, 0)),
          Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, offset: const Offset(2, 2)),
          Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, offset: const Offset(-2, -2)),
          Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, offset: const Offset(2, -2)),
          Shadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 2, offset: const Offset(-2, 2)),
          Shadow(color: color.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (item.kind == _FxKind.float) {
          final scale = Curves.elasticOut.transform(min(1.0, t * 2.2)) ;
          final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
          return Positioned(
            left: item.pos.dx - 150,
            top: item.pos.dy - item.size - Curves.easeOutCubic.transform(t) * item.rise,
            width: 300,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Text(item.text, textAlign: TextAlign.center, style: _style(item.size, item.color)),
              ),
            ),
          );
        }
        // 배너: 튀어나오고 → 잠깐 머물고 → 위로 사라짐
        final inT = Curves.elasticOut.transform(min(1.0, t / 0.35));
        final outT = t > 0.75 ? Curves.easeIn.transform((t - 0.75) / 0.25) : 0.0;
        final tilt = sin(t * pi * 2) * 0.03;
        return Align(
          alignment: Alignment(0, -0.15 + item.pos.dy),
          child: Opacity(
            opacity: (1 - outT).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -outT * 60),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scale: inT * (1 + outT * 0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.text, textAlign: TextAlign.center, style: _style(item.size, item.color)),
                      if (item.sub != null) ...[
                        const SizedBox(height: 6),
                        Text(item.sub!, textAlign: TextAlign.center, style: _style(item.size * 0.4, Palette.ink)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
