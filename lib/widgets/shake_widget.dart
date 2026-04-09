import 'package:flutter/material.dart';

class ShakeWidget extends StatefulWidget {
  final Widget child;

  const ShakeWidget({super.key, required this.child});

  @override
  ShakeWidgetState createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake({double amplitude = 1.0}) {
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -8.0 * amplitude), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -8.0 * amplitude, end: 8.0 * amplitude),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: 8.0 * amplitude, end: -6.0 * amplitude),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: -6.0 * amplitude, end: 6.0 * amplitude),
          weight: 2),
      TweenSequenceItem(
          tween: Tween(begin: 6.0 * amplitude, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) =>
          Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
      child: widget.child,
    );
  }
}
