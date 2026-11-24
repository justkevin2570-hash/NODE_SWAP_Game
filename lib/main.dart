import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage.dart';
import 'ui/widgets/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 휴대폰은 세로 고정, 태블릿(짧은 변 600dp 이상)은 가로·세로 모두 (app.dart 의 OrientationPolicy 가 이어서 관리).
  await SystemChrome.setPreferredOrientations(orientationsFor(_startShortestSide()));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const SymmetryRushApp(),
  ));
}

double _startShortestSide() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return view.physicalSize.shortestSide / view.devicePixelRatio;
}
