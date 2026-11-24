import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 태블릿처럼 짧은 변이 이만큼 이상이면 가로 화면도 허용한다 (휴대폰은 세로 고정).
const double kTabletShortestSide = 600;

/// 가로로 넓은 화면(태블릿 가로, 넓은 웹 창)인지. 이때 화면들은 두 칸 배치를 쓴다.
bool isWideLandscape(Size size) => size.width >= size.height * 1.2 && size.height >= 480;

bool isWideOf(BuildContext context) => isWideLandscape(MediaQuery.sizeOf(context));

/// 화면 내용의 최대 폭: 휴대폰 480, 세로 태블릿 640, 가로로 넓은 화면은 [wide].
double contentMaxWidth(BuildContext context, {double wide = 1100}) {
  final size = MediaQuery.sizeOf(context);
  if (isWideLandscape(size)) return wide;
  return size.shortestSide >= kTabletShortestSide ? 640 : 480;
}

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

/// 기기 크기에 맞는 화면 방향.
List<DeviceOrientation> orientationsFor(double shortestSide) => shortestSide >= kTabletShortestSide
    ? const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitDown,
      ]
    : const [DeviceOrientation.portraitUp];

/// 접는 폰을 펼치거나 접어서 화면 크기가 바뀌면 허용 방향을 다시 정한다.
class OrientationPolicy extends StatefulWidget {
  const OrientationPolicy({super.key, required this.child});

  final Widget child;

  @override
  State<OrientationPolicy> createState() => _OrientationPolicyState();
}

class _OrientationPolicyState extends State<OrientationPolicy> {
  bool? _tablet;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletShortestSide;
    if (tablet != _tablet) {
      _tablet = tablet;
      SystemChrome.setPreferredOrientations(orientationsFor(tablet ? kTabletShortestSide : 0));
    }
    return widget.child;
  }
}
