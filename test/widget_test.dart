import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/app.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/game_state.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/ui/screens/game_screen.dart';
import 'package:node_swap_game/ui/widgets/board_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(p),
    audioProvider.overrideWithValue(AudioEngine.silent()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SymmetryRushApp()));
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

/// 남은 지연 타이머를 흘려보내고 화면을 정리한다.
Future<void> _cleanup(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('타이틀 화면이 뜬다', (tester) async {
    await _pumpApp(tester);
    expect(find.text('러시 시작'), findsOneWidget);
    expect(find.text('클래식'), findsOneWidget);
    expect(find.byType(BoardView), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('처음 러시를 누르면 튜토리얼부터', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1. 바꿔서 맞추기'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('러시 한 판: 카운트다운 → 최적 풀이로 클리어 → 다음 스테이지', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GameScreen), findsOneWidget);

    // 카운트다운 3-2-1-GO
    await tester.pump(const Duration(milliseconds: 2000));
    var s = container.read(gameProvider)!;
    expect(s.phase, Phase.playing);
    expect(s.stage, 1);

    // solver 로 정답을 찾아 그대로 둔다
    final sol = Solver(s.target).solve(s.board)!;
    final ctrl = container.read(gameProvider.notifier);
    for (final (a, b) in sol.swaps) {
      ctrl.swap(a, b);
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (sol.needsRotation) {
      ctrl.rotate();
      await tester.pump(const Duration(milliseconds: 100));
    }
    s = container.read(gameProvider)!;
    expect(s.cleared, 1);
    expect(s.score, greaterThan(0));
    expect(s.combo, 1);

    await tester.pump(const Duration(milliseconds: 1000));
    s = container.read(gameProvider)!;
    expect(s.phase, Phase.playing);
    expect(s.stage, 2);
    expect(s.movesUsed, 0);

    // 일시정지하면 시간이 멈춘다
    ctrl.pause();
    final frozen = container.read(gameProvider)!.remainingMs;
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(gameProvider)!.remainingMs, frozen);
    expect(find.text('잠깐 쉬어요'), findsOneWidget);
    ctrl.resume();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(gameProvider)!.remainingMs, lessThan(frozen));

    // 패스하면 시간 감점 + 새 퍼즐
    final before = container.read(gameProvider)!.remainingMs;
    ctrl.skip();
    await tester.pump(const Duration(milliseconds: 800));
    s = container.read(gameProvider)!;
    expect(s.remainingMs, lessThan(before - 2500));
    expect(s.stage, 2);
    expect(s.phase, Phase.playing);

    ctrl.quit();
    await _cleanup(tester);
  });

  testWidgets('러시: 시간이 다 되면 결과 화면', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 2000));
    for (int i = 0; i < 65; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(gameProvider)?.phase, Phase.over);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('한 번 더!'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('러시: 5연속 빠른 클리어 → 피버 (시간 정지)', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 2000));
    final ctrl = container.read(gameProvider.notifier);

    Future<void> solveCurrent() async {
      final s = container.read(gameProvider)!;
      final sol = Solver(s.target).solve(s.board)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (int i = 0; i < 5; i++) {
      await solveCurrent();
      // 전환 연출이 끝날 때까지
      await tester.pump(const Duration(milliseconds: 900));
    }
    var s = container.read(gameProvider)!;
    expect(s.cleared, 5);
    expect(s.combo, 5);
    expect(s.isFever, isTrue);
    expect(find.text('FEVER'), findsOneWidget);

    final frozen = s.remainingMs;
    await tester.pump(const Duration(seconds: 3));
    s = container.read(gameProvider)!;
    expect(s.remainingMs, frozen);
    expect(s.feverMs, lessThan(6000));

    // 피버 중 클리어는 점수 2배
    final before = s.score;
    await solveCurrent();
    final gain = container.read(gameProvider)!.score - before;
    expect(gain, greaterThan(500));

    await tester.pump(const Duration(seconds: 8));
    expect(container.read(gameProvider)!.isFever, isFalse);
    ctrl.quit();
    await _cleanup(tester);
  });

  testWidgets('클래식: 풀면 별과 함께 결과 화면', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('클래식'));
    await tester.pump();
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('보통'));
    await tester.pump();
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 2000));
    final s = container.read(gameProvider)!;
    expect(s.phase, Phase.playing);
    final sol = Solver(s.target).solve(s.board)!;
    final ctrl = container.read(gameProvider.notifier);
    for (final (a, b) in sol.swaps) {
      ctrl.swap(a, b);
    }
    if (sol.needsRotation) ctrl.rotate();
    await tester.pump(const Duration(milliseconds: 100));
    final done = container.read(gameProvider)!;
    expect(done.phase, Phase.over);
    expect(done.won, isTrue);
    expect(done.stars, 3);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('CLEAR!'), findsOneWidget);
    expect(find.text('다음 퍼즐'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('성능: 시간이 흘러도 보드는 다시 빌드되지 않고, 퍼즐이 바뀌어도 기록이 쌓이지 않는다', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 2000));
    expect(container.read(gameProvider)!.phase, Phase.playing);

    // 가만히 3초: 시간 막대만 바뀌어야 한다 (예전엔 50ms 마다 보드 전체가 다시 빌드됐다)
    BoardViewState.debugBuildCount = 0;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(BoardViewState.debugBuildCount, lessThanOrEqualTo(2));

    // 퍼즐을 여러 번 바꿔도 보드가 기억하는 타일 수는 25개 이하
    final ctrl = container.read(gameProvider.notifier);
    for (int i = 0; i < 8; i++) {
      ctrl.skip();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final board = tester.state<BoardViewState>(find.byType(BoardView).last);
    expect(board.debugTrackedTiles, lessThanOrEqualTo(25));

    ctrl.quit();
    await _cleanup(tester);
  });
}
