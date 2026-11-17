import 'package:flutter/material.dart';

import '../game/logic/symmetry.dart';

/// 파스텔 팔레트.
abstract final class Palette {
  // 배경
  static const cream = Color(0xFFFFF8F1);
  static const blush = Color(0xFFFDEFF5);
  static const mist = Color(0xFFF1EEFF);

  // 글자
  static const ink = Color(0xFF4B4263);
  static const inkSoft = Color(0xFF8B83A3);
  static const inkFaint = Color(0xFFC4BDD6);

  // 포인트 (밝은 색 / 진한 색)
  static const lavender = Color(0xFFC9BDFF);
  static const lavenderDeep = Color(0xFF9A87F2);
  static const mint = Color(0xFFAEEBD8);
  static const mintDeep = Color(0xFF5FCCAB);
  static const peach = Color(0xFFFFCDB5);
  static const peachDeep = Color(0xFFFF9E7D);
  static const pink = Color(0xFFFFC2D9);
  static const pinkDeep = Color(0xFFF77FAB);
  static const sky = Color(0xFFBDE0FF);
  static const skyDeep = Color(0xFF6DB5F2);
  static const butter = Color(0xFFFFEBA6);
  static const butterDeep = Color(0xFFF7C948);

  static const white = Color(0xFFFFFFFF);
  static const danger = Color(0xFFFF7A93);

  static const blobs = [lavender, mint, peach, pink, sky, butter];

  /// 대칭 종류별 테마 색. (밝은 색, 진한 색)
  static (Color, Color) forSymmetry(SymmetryType t) => switch (t) {
        SymmetryType.horizontal => (pink, pinkDeep),
        SymmetryType.vertical => (sky, skyDeep),
        SymmetryType.point => (mint, mintDeep),
      };

  static const fever = [pinkDeep, peachDeep, butterDeep, mintDeep, skyDeep, lavenderDeep];
}
