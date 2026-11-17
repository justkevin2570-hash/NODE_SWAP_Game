import 'package:flutter/material.dart';

import 'palette.dart';

const kFont = 'Jua';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.lavenderDeep,
    surface: Palette.cream,
  ).copyWith(primary: Palette.lavenderDeep, onSurface: Palette.ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFont,
    scaffoldBackgroundColor: Palette.cream,
    textTheme: const TextTheme().apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
      fontFamily: kFont,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.lavenderDeep,
      inactiveTrackColor: Palette.mist,
      thumbColor: Palette.lavenderDeep,
      trackHeight: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Palette.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.mintDeep
            : Palette.inkFaint,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// 공통 텍스트 스타일.
abstract final class TextStyles {
  static const display = TextStyle(
    fontFamily: kFont,
    fontSize: 44,
    color: Palette.ink,
    height: 1.0,
  );
  static const title = TextStyle(fontFamily: kFont, fontSize: 26, color: Palette.ink);
  static const body = TextStyle(fontFamily: kFont, fontSize: 16, color: Palette.ink);
  static const caption = TextStyle(fontFamily: kFont, fontSize: 13, color: Palette.inkSoft);
  static const number = TextStyle(
    fontFamily: kFont,
    fontSize: 28,
    color: Palette.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// 부드러운 파스텔 그림자.
List<BoxShadow> softShadow(Color color, {double blur = 18, double y = 8, double opacity = 0.35}) => [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
