import 'package:flutter/material.dart';

/// 넓은 화면(웹·태블릿)에서도 휴대폰 세로 비율로 가운데 정렬한다.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 살짝 커지며 페이드되는 화면 전환.
Route<T> softRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 1.06, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
