import 'dart:async';

import 'package:node_swap_game/core/l10n.dart';

/// 모든 테스트 전에 실행된다. 테스트 기기 언어(영어)와 상관없이 한국어 화면으로 검사한다.
/// (영어 화면은 test/l10n_test.dart 에서 따로 검사한다.)
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  appLang = AppLang.ko;
  await testMain();
}
