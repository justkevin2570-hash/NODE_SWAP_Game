import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/app.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/game_state.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/ui/screens/tutorial_screen.dart';
import 'package:node_swap_game/ui/widgets/board_view.dart';
import 'package:node_swap_game/ui/widgets/layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('휴대폰은 세로 고정, 태블릿은 가로도 허용', () {
    expect(orientationsFor(411), [DeviceOrientation.portraitUp]);
    expect(orientationsFor(800), contains(DeviceOrientation.landscapeLeft));
    expect(isWideLandscape(const Size(1280, 800)), isTrue);
    expect(isWideLandscape(const Size(800, 1280)), isFalse);
    expect(isWideLandscape(const Size(360, 780)), isFalse);
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester, Size dp) async {
    tester.view.physicalSize = dp * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'flutter.tutorialSeen': true});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      audioProvider.overrideWithValue(AudioEngine.silent()),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const SymmetryRushApp()));
    await settle(tester, 20);
    return c;
  }

  for (final dp in [const Size(1280, 800), const Size(800, 1280)]) {
    final land = dp.width > dp.height;
    testWidgets('태블릿 ${land ? '가로' : '세로'} ${dp.width.toInt()}x${dp.height.toInt()}: 모든 화면이 넘치지 않고 판이 크다',
        (tester) async {
      final c = await pumpApp(tester, dp);
      expect(find.text('러시 시작'), findsOneWidget);
      // 배우기
      await tester.tap(find.text('배우기'));
      await settle(tester, 15);
      expect(find.byType(TutorialScreen), findsOneWidget);
      expect(tester.getSize(find.byType(BoardView)).width, greaterThan(380));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester, 10);
      // 스테이지 → 9x9 → 1탄
      await tester.tap(find.text('스테이지'));
      await settle(tester, 8);
      await tester.tap(find.text('9x9'));
      await settle(tester, 8);
      await tester.tap(find.text('1').first);
      await settle(tester, 25);
      final ctrl = c.read(gameProvider.notifier);
      expect(c.read(gameProvider)!.boardSize, BoardSize.nine);
      final board = tester.getSize(find.byType(BoardView)).width;
      expect(board, greaterThan(land ? 640 : 560), reason: '판 크기 $board');
      ctrl.pause();
      await settle(tester, 5);
      expect(find.text('잠깐 쉬어요'), findsOneWidget);
      ctrl.resume();
      await settle(tester, 3);
      // 풀고 결과 화면
      final s = c.read(gameProvider)!;
      final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
      await settle(tester, 30);
      expect(find.text('CLEAR!'), findsOneWidget);
      expect(find.text('다음 탄'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  testWidgets('게임 중에 태블릿을 돌려도 같은 판이 이어진다', (tester) async {
    final c = await pumpApp(tester, const Size(800, 1280));
    await tester.tap(find.text('스테이지'));
    await settle(tester, 8);
    await tester.tap(find.text('7x7'));
    await settle(tester, 8);
    await tester.tap(find.text('1').first);
    await settle(tester, 25);
    final ctrl = c.read(gameProvider.notifier);
    var s = c.read(gameProvider)!;
    final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
    final (a, b) = sol.swaps.first;
    ctrl.swap(a, b);
    await settle(tester, 3);
    final before = c.read(gameProvider)!;
    final portraitBoard = tester.getSize(find.byType(BoardView)).width;
    // 가로로 돌린다
    tester.view.physicalSize = const Size(1280, 800) * 2;
    await settle(tester, 5);
    s = c.read(gameProvider)!;
    expect(s.phase, Phase.playing);
    expect(s.board, before.board);
    expect(s.movesUsed, before.movesUsed);
    expect(s.remainingMs, lessThanOrEqualTo(before.remainingMs));
    expect(find.byType(BoardView), findsOneWidget);
    expect(tester.getSize(find.byType(BoardView)).width, isNot(portraitBoard));
    // 다시 세로로
    tester.view.physicalSize = const Size(800, 1280) * 2;
    await settle(tester, 5);
    expect(c.read(gameProvider)!.board, before.board);
    ctrl.quit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<void> settle(WidgetTester tester, [int n = 10]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
