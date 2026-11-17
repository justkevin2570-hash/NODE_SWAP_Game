import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';

/// 누르면 말랑하게 눌리는 파스텔 버튼.
class BubblyButton extends ConsumerStatefulWidget {
  const BubblyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Palette.lavender,
    this.deep = Palette.lavenderDeep,
    this.height = 60,
    this.fontSize = 22,
    this.width,
    this.subtitle,
    this.glow = false,
    this.sound = Sfx.button,
    this.vertical = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color deep;
  final double height;
  final double? width;
  final double fontSize;
  final bool glow;
  final Sfx? sound;

  /// 아이콘 위, 글자 아래로 쌓는 좁은 버튼.
  final bool vertical;

  @override
  ConsumerState<BubblyButton> createState() => _BubblyButtonState();
}

class _BubblyButtonState extends ConsumerState<BubblyButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.glow) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BubblyButton old) {
    super.didUpdateWidget(old);
    if (widget.glow && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!widget.glow && _glow.isAnimating) {
      _glow
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _down ? 2.0 : 6.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              final audio = ref.read(audioProvider);
              audio.unlock();
              if (widget.sound != null) audio.play(widget.sound!);
              audio.haptic(HapticKind.selection);
              widget.onPressed!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) => AnimatedScale(
          scale: _down ? 0.95 : 1.0 + _glow.value * 0.05,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.vertical ? 24 : widget.height / 2),
              boxShadow: [
                BoxShadow(
                  color: (enabled ? widget.deep : Color.lerp(widget.deep, Colors.white, 0.5)!).withValues(alpha: enabled ? 0.9 : 0.6),
                  offset: Offset(0, depth),
                ),
                BoxShadow(
                  color: widget.deep.withValues(alpha: 0.25 + _glow.value * 0.5),
                  blurRadius: 16 + _glow.value * 26,
                  spreadRadius: _glow.value * 4,
                  offset: Offset(0, depth + 4),
                ),
              ],
            ),
            transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
            child: child,
          ),
        ),
        child: _face(enabled),
      ),
    );
  }

  Widget _face(bool enabled) {
    final c = enabled ? widget.color : Color.lerp(widget.color, Colors.white, 0.6)!;
    final ink = enabled ? Palette.ink : Palette.inkFaint;
    final hasLabel = widget.label.isNotEmpty;
    final labelText = Text(
      widget.label,
      maxLines: 1,
      style: TextStyle(fontFamily: kFont, fontSize: widget.fontSize, color: ink, height: 1.1),
    );
    final sub = widget.subtitle == null
        ? null
        : Text(
            widget.subtitle!,
            maxLines: 1,
            style: TextStyle(
              fontFamily: kFont,
              fontSize: widget.fontSize * (widget.vertical ? 0.62 : 0.55),
              color: ink.withValues(alpha: 0.65),
              height: 1.1,
            ),
          );
    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, color: ink, size: hasLabel ? widget.fontSize + 2 : widget.fontSize * 1.1);

    final Widget content;
    if (!hasLabel) {
      content = icon ?? const SizedBox();
    } else if (widget.vertical) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [?icon, labelText, ?sub],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 8)],
          Column(mainAxisSize: MainAxisSize.min, children: [labelText, ?sub]),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.vertical ? 24 : widget.height / 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(c, Colors.white, 0.35)!, c],
          ),
        ),
        child: Stack(
          children: [
            // 윗부분 광택
            Positioned(
              left: widget.height * 0.3,
              right: widget.height * 0.3,
              top: 5,
              height: widget.height * (widget.vertical ? 0.18 : 0.28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(widget.height),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hasLabel ? 12 : 0, vertical: 4),
                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: content)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 둥근 원형 아이콘 버튼.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = Palette.white,
    this.deep = Palette.lavender,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color deep;
  final double size;

  @override
  Widget build(BuildContext context) => BubblyButton(
        label: '',
        icon: icon,
        onPressed: onPressed,
        color: color,
        deep: deep,
        height: size,
        width: size,
        fontSize: size * 0.42,
      );
}

/// 반투명 유리 카드.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.color = Colors.white,
    this.opacity = 0.62,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 작은 알약 모양 라벨.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    this.color = Palette.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(40),
          boxShadow: softShadow(Palette.lavenderDeep, blur: 10, y: 3, opacity: 0.15),
        ),
        child: child,
      );
}
