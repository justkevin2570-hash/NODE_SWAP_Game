import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/app.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/l10n.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => appLang = AppLang.ko);

  test('코드에서 tr() 로 쓰는 문구는 모두 영어 번역이 있다', () {
    final call = RegExp(r"tr\('((?:[^'\\]|\\.)*)'");
    final keys = debugTranslationKeys.toSet();
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('l10n.dart')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        final key = m.group(1)!.replaceAll(r'\n', '\n');
        if (!keys.contains(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('값 채우기와 언어 전환', () {
    appLang = AppLang.ko;
    expect(tr('{n}일 연속', {'n': 3}), '3일 연속');
    expect(SymmetryType.horizontal.label, '좌우 대칭');
    appLang = AppLang.en;
    expect(tr('{n}일 연속', {'n': 3}), '3-day streak');
    expect(tr('{size} {n}탄', {'size': '7x7', 'n': 12}), '7x7  Stage 12');
    expect(SymmetryType.horizontal.label, 'Left-Right');
    // 수식 중괄호는 그대로 남는다
    expect(tr('{y = x} 대칭'), '{y = x} symmetry');
  });

  for (final lang in AppLang.values) {
    testWidgets('360dp 폰 (${lang.name}): 타이틀·설정·스테이지·9x9 게임·일시정지·결과에 넘치는 곳 없음', (tester) async {
      appLang = lang;
      final en = lang == AppLang.en;
      tester.view.physicalSize = const Size(1080, 2340); // 360 x 780 dp
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'flutter.tutorialSeen': true});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(prefs),
        audioProvider.overrideWithValue(AudioEngine.silent()),
      ]);
      addTearDown(c.dispose);
      Future<void> settle([int n = 10]) async {
        for (int i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const SymmetryRushApp()));
      await settle(20);
      expect(find.text(en ? 'Start Rush' : '러시 시작'), findsOneWidget);
      // 설정
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await settle(8);
      expect(find.text(en ? 'Settings' : '설정'), findsOneWidget);
      await tester.tapAt(const Offset(180, 40)); // 시트 밖을 눌러 닫기
      await settle(8);
      // 스테이지 → 9x9
      await tester.tap(find.text(en ? 'Stages' : '스테이지'));
      await settle(8);
      await tester.tap(find.text('9x9'));
      await settle(8);
      expect(find.text(en ? 'Stages | 9x9' : '스테이지 | 9x9'), findsOneWidget);
      await tester.tap(find.text('1').first);
      await settle(25);
      final ctrl = c.read(gameProvider.notifier);
      expect(c.read(gameProvider)!.boardSize, BoardSize.nine);
      expect(find.text(en ? '9x9  Stage 1' : '9x9 1탄'), findsOneWidget);
      // 일시정지
      ctrl.pause();
      await settle(5);
      expect(find.text(en ? 'Paused' : '잠깐 쉬어요'), findsOneWidget);
      ctrl.resume();
      await settle(3);
      // 풀고 결과 화면
      final s = c.read(gameProvider)!;
      final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
      await settle(30);
      expect(find.text('CLEAR!'), findsOneWidget);
      expect(find.text(en ? 'Next Stage' : '다음 탄'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
