import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/app.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/game_state.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/ui/screens/stage_map_screen.dart';
import 'package:node_swap_game/game/logic/stages.dart';
import 'package:node_swap_game/online/leaderboard.dart';
import 'package:node_swap_game/ui/screens/game_screen.dart';
import 'package:node_swap_game/ui/widgets/board_view.dart';
import 'package:node_swap_game/ui/widgets/tile_view.dart';
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
    leaderboardProvider.overrideWithValue(const DisabledLeaderboard()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SymmetryRushApp()));
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

/// 타이틀 → 클래식 → 난이도 → 스테이지 맵 → [stage]탄 시작 (카운트다운 전까지).
Future<void> _openStage(WidgetTester tester, String boardSize, {int stage = 1}) async {
  await tester.tap(find.text('클래식'));
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text(boardSize));
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.descendant(of: find.byType(StageTile), matching: find.text('$stage')).first);
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

  testWidgets('오늘의 퍼즐: 타이틀에서 시작 → 풀면 1일 연속, 타이틀에 완료 표시', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    expect(find.text('오늘의 퍼즐'), findsOneWidget);
    await tester.tap(find.text('오늘의 퍼즐'));
    await tester.pump();
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final s = container.read(gameProvider)!;
    expect(s.isDaily, isTrue);
    expect(s.stageNumber, isNull);
    expect(find.textContaining('오늘의 퍼즐'), findsOneWidget);
    final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
    final ctrl = container.read(gameProvider.notifier);
    for (final (a, b) in sol.swaps) {
      ctrl.swap(a, b);
    }
    if (sol.needsRotation) ctrl.rotate();
    final done = container.read(gameProvider)!;
    expect(done.won, isTrue);
    expect(done.dailyStreak, 1);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1일 연속'), findsOneWidget);
    expect(find.text('다음 탄'), findsNothing);
    expect(find.text('다시 하기'), findsOneWidget);
    await tester.tap(find.text('홈으로'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('오늘 완료!'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('클래식: 풀면 별과 함께 결과 화면', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await _openStage(tester, '5x5');
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
    expect(find.text('다음 탄'), findsOneWidget);
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

  group('앱 밖으로 나갔다 돌아올 때', () {
    Future<void> leaveApp(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }

    Future<void> comeBack(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    Future<ProviderContainer> startRush(WidgetTester tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await tester.tap(find.text('러시 시작'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 2000));
      return container;
    }

    testWidgets('러시: 5분 넘게 비우면 판이 끝나고 점수가 기록된다', (tester) async {
      final container = await startRush(tester);
      final ctrl = container.read(gameProvider.notifier);
      // 한 판 풀어서 점수를 만든다
      final s0 = container.read(gameProvider)!;
      final sol = Solver(s0.target).solve(s0.board)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
      await tester.pump(const Duration(milliseconds: 900));
      final score = container.read(gameProvider)!.score;
      expect(score, greaterThan(0));

      await leaveApp(tester);
      expect(container.read(gameProvider)!.phase, Phase.paused);
      final remaining = container.read(gameProvider)!.remainingMs;
      await tester.pump(const Duration(minutes: 5, seconds: 1));
      // 나가 있는 동안 시간이 흐르지 않았다
      expect(container.read(gameProvider)!.remainingMs, remaining);
      await comeBack(tester);
      await tester.pump();

      final s = container.read(gameProvider)!;
      expect(s.phase, Phase.over);
      expect(s.expired, isTrue);
      expect(container.read(recordsProvider).rushBestScore, score);
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('한 번 더!'), findsOneWidget);
      expect(find.text('신기록!'), findsOneWidget); // 첫 기록이라 신기록
      await _cleanup(tester);
    });

    testWidgets('러시: 5분 안에 돌아오면 일시정지 상태로 이어서 한다', (tester) async {
      final container = await startRush(tester);
      await leaveApp(tester);
      await tester.pump(const Duration(minutes: 4, seconds: 50));
      await comeBack(tester);
      await tester.pump();
      final s = container.read(gameProvider)!;
      expect(s.phase, Phase.paused);
      expect(s.expired, isFalse);
      expect(find.text('잠깐 쉬어요'), findsOneWidget);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });

    testWidgets('러시: 퍼즐 전환 순간에 나가도 시간이 흐르지 않는다', (tester) async {
      final container = await startRush(tester);
      final ctrl = container.read(gameProvider.notifier);
      ctrl.skip(); // 전환 단계로
      expect(container.read(gameProvider)!.phase, Phase.transition);
      await leaveApp(tester);
      final remaining = container.read(gameProvider)!.remainingMs;
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(gameProvider)!.remainingMs, remaining);
      expect(container.read(gameProvider)!.phase, Phase.paused);
      await comeBack(tester);
      ctrl.resume();
      await tester.pump(const Duration(milliseconds: 900));
      expect(container.read(gameProvider)!.phase, Phase.playing);
      ctrl.quit();
      await _cleanup(tester);
    });

    testWidgets('포커스만 잃어도(화면 분할, 알림창) 게임이 멈추고 시간이 흐르지 않는다', (tester) async {
      final container = await startRush(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final s = container.read(gameProvider)!;
      expect(s.phase, Phase.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(container.read(gameProvider)!.remainingMs, s.remainingMs);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('잠깐 쉬어요'), findsOneWidget);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });

    testWidgets('클래식: 오래 비워도 끝내지 않는다', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await _openStage(tester, '5x5');
      await tester.pump(const Duration(milliseconds: 2000));
      await leaveApp(tester);
      await tester.pump(const Duration(minutes: 30));
      await comeBack(tester);
      await tester.pump();
      final s = container.read(gameProvider)!;
      expect(s.phase, Phase.paused);
      expect(s.expired, isFalse);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });
  });

  testWidgets('배터리: 가만히 있을 때 화면을 매 프레임 다시 그리지 않는다', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // 카운트다운·등장 연출이 끝날 때까지
    }
    expect(container.read(gameProvider)!.phase, Phase.playing);

    // 1초 동안 10ms 간격으로, 다음 프레임 요청이 있는지 센다 (매 프레임 애니메이션이면 ~100)
    var scheduled = 0;
    for (int i = 0; i < 100; i++) {
      if (tester.binding.hasScheduledFrame) scheduled++;
      await tester.pump(const Duration(milliseconds: 10));
    }
    // ignore: avoid_print
    print('1초 동안 프레임 요청: $scheduled / 100');
    expect(scheduled, lessThan(40));

    container.read(gameProvider.notifier).quit();
    await _cleanup(tester);
  });

  group('되돌리기', () {
    /// [stage]탄 시작. 71탄부터는 여유 이동 0, 되돌리기 2번.
    Future<ProviderContainer> startClassic(WidgetTester tester, {int stage = 1}) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true, 'stageStars_5x5': '3' * (stage - 1)});
      await _openStage(tester, '5x5', stage: stage);
      await tester.pump(const Duration(milliseconds: 2000));
      return container;
    }

    /// 지금 보드에서 두면 바로 막히는 swap 을 찾는다.
    (int, int)? findStuckMove(GameSession s) {
      for (final (a, b) in s.board.grid.adjacentPairs) {
        if (s.board[a] == s.board[b]) continue;
        final after = s.board.swap(a, b);
        if (after.isSymmetric(s.target)) continue;
        if (Solver(s.target).solve(after, maxDepth: s.movesLeft - 1) == null) return (a, b);
      }
      return null;
    }

    testWidgets('막히면 바로 실패하지 않고, 되돌리기로 살린 뒤 클리어할 수 있다', (tester) async {
      final container = await startClassic(tester, stage: 71); // 여유 이동 0, 되돌리기 2번
      final ctrl = container.read(gameProvider.notifier);
      var s = container.read(gameProvider)!;
      expect(s.stageNumber, 71);
      expect(s.maxMoves, s.puzzle.par);
      expect(s.undosLeft, 2);
      final bad = findStuckMove(s)!;
      final startBoard = s.board;

      ctrl.swap(bad.$1, bad.$2);
      await tester.pump(const Duration(milliseconds: 50));
      s = container.read(gameProvider)!;
      expect(s.stuck, isTrue);
      expect(s.phase, Phase.playing);
      // 막힌 동안에는 타일·회전이 안 된다
      final frozen = s.board;
      ctrl.rotate();
      expect(container.read(gameProvider)!.board, frozen);

      ctrl.undo();
      s = container.read(gameProvider)!;
      expect(s.stuck, isFalse);
      expect(s.board, startBoard);
      expect(s.movesUsed, 0);
      expect(s.undosLeft, 1);

      final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
      expect(container.read(gameProvider)!.won, isTrue);
      await _cleanup(tester);
    });

    testWidgets('되돌리기를 다 쓰면 막혔을 때 예전처럼 실패한다', (tester) async {
      final container = await startClassic(tester, stage: 71);
      final ctrl = container.read(gameProvider.notifier);
      var s = container.read(gameProvider)!;
      final bad = findStuckMove(s)!;
      for (int i = 0; i < 2; i++) {
        ctrl.swap(bad.$1, bad.$2);
        ctrl.undo();
      }
      expect(container.read(gameProvider)!.undosLeft, 0);
      ctrl.swap(bad.$1, bad.$2);
      await tester.pump(const Duration(milliseconds: 50));
      s = container.read(gameProvider)!;
      expect(s.phase, Phase.over);
      expect(s.won, isFalse);
      await _cleanup(tester);
    });

    testWidgets('막힌 게 아니어도 한 수씩 무를 수 있고, 무를 게 없으면 버튼이 꺼진다', (tester) async {
      final container = await startClassic(tester); // 되돌리기 3번
      final ctrl = container.read(gameProvider.notifier);
      var s = container.read(gameProvider)!;
      expect(s.canUndo, isFalse); // 아직 둔 수가 없다
      final sol = Solver(s.target).solve(s.board)!;
      final (a, b) = sol.swaps.first;
      final before = s.board;
      ctrl.swap(a, b);
      s = container.read(gameProvider)!;
      if (s.phase == Phase.over) return _cleanup(tester); // 한 수에 끝나는 판
      expect(s.canUndo, isTrue);
      ctrl.undo();
      s = container.read(gameProvider)!;
      expect(s.board, before);
      expect(s.undosLeft, 2);
      expect(s.canUndo, isFalse);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });
  });

  testWidgets('짝 칸 표시: 클래식에서 타일을 고르면 짝 칸이 보이고, 설정으로 끌 수 있다. 러시에서는 안 보인다', (tester) async {
    final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
    final ctrl = container.read(gameProvider.notifier);
    int marked() => tester.widgetList<TileView>(find.byType(TileView)).where((t) => t.pairMark).length;
    int offAxis(GameSession s) => List.generate(25, (i) => i).firstWhere((i) => s.board.grid.partnerOf(s.target, i) != i);

    // 클래식: 보인다
    await _openStage(tester, '5x5');
    await tester.pump(const Duration(milliseconds: 2000));
    ctrl.tapCell(offAxis(container.read(gameProvider)!));
    await tester.pump();
    expect(marked(), 1);
    container.read(settingsProvider.notifier).setPairPreview(false);
    await tester.pump();
    expect(marked(), 0);
    container.read(settingsProvider.notifier).setPairPreview(true);

    // 러시: 켜져 있어도 안 보인다
    ctrl.start(GameMode.rush);
    await tester.pump(const Duration(milliseconds: 2000));
    ctrl.tapCell(offAxis(container.read(gameProvider)!));
    await tester.pump();
    expect(container.read(gameProvider)!.selected, isNotNull);
    expect(marked(), 0);
    ctrl.quit();
    await _cleanup(tester);
  });

  group('클래식 스테이지', () {
    Future<void> toResult(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 1700));
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapAndStart(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 2000)); // 카운트다운
    }

    void solve(ProviderContainer c) {
      final ctrl = c.read(gameProvider.notifier);
      final s = c.read(gameProvider)!;
      final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
    }

    testWidgets('1탄 클리어 → 별 저장, 2탄이 열리고 [다음 탄]으로 2탄 시작', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await _openStage(tester, '5x5');
      await tester.pump(const Duration(milliseconds: 2000));
      final first = container.read(gameProvider)!;
      expect(first.stageNumber, 1);
      expect(first.board, stagePuzzle(BoardSize.five, 1).board);
      solve(container);
      expect(container.read(gameProvider)!.won, isTrue);
      final progress = container.read(stageProgressProvider);
      expect(progress.starsOf(BoardSize.five, 1), 3);
      expect(progress.isUnlocked(BoardSize.five, 2), isTrue);
      expect(progress.isUnlocked(BoardSize.five, 3), isFalse);
      await toResult(tester);
      expect(find.text('별 +3'), findsNothing); // 장식 문자 포함 문구
      expect(find.textContaining('별 +3'), findsOneWidget);
      expect(find.text('다음 탄'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);

      await tapAndStart(tester, '다음 탄');
      final second = container.read(gameProvider)!;
      expect(second.stageNumber, 2);
      expect(second.board, stagePuzzle(BoardSize.five, 2).board);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });

    testWidgets('다시 하기: 같은 탄을 처음부터, 별은 더 많을 때만 바뀐다', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true, 'stageStars_5x5': '3'});
      final notifier = container.read(stageProgressProvider.notifier);
      // 이미 별 3개인 탄을 더 적게 깨도 그대로
      expect(notifier.record(BoardSize.five, 1, 1), 0);
      expect(container.read(stageProgressProvider).starsOf(BoardSize.five, 1), 3);
      // 2탄이 열려 있다
      await _openStage(tester, '5x5', stage: 2);
      await tester.pump(const Duration(milliseconds: 2000));
      final first = container.read(gameProvider)!;
      expect(first.stageNumber, 2);
      // 힌트를 쓰고 클리어
      container.read(gameProvider.notifier).useHint();
      solve(container);
      await toResult(tester);
      await tapAndStart(tester, '다시 하기');
      final again = container.read(gameProvider)!;
      expect(again.stageNumber, 2);
      expect(again.board, first.board);
      expect(again.movesUsed, 0);
      expect(again.hintsLeft, Rules.classicHints(2));
      expect(again.undosLeft, Rules.classicUndos(2));
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });

    testWidgets('실패 → [다시 하기]만, 다음 탄은 열리지 않는다', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await _openStage(tester, '5x5');
      await tester.pump(const Duration(milliseconds: 2000));
      final first = container.read(gameProvider)!;
      for (int i = 0; i < 62; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(container.read(gameProvider)!.phase, Phase.over);
      expect(container.read(stageProgressProvider).isUnlocked(BoardSize.five, 2), isFalse);
      await toResult(tester);
      expect(find.text('다시 하기'), findsOneWidget);
      expect(find.text('다음 탄'), findsNothing);
      expect(find.text('스테이지 목록'), findsOneWidget);
      await tapAndStart(tester, '다시 하기');
      expect(container.read(gameProvider)!.board, first.board);
      container.read(gameProvider.notifier).quit();
      await _cleanup(tester);
    });

    testWidgets('판 크기: 5x5·7x7·9x9 모두 처음부터 열려 있다', (tester) async {
      await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await tester.tap(find.text('클래식'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      await tester.tap(find.text('9x9'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(StageMapScreen), findsOneWidget);
      expect(find.text('클래식 | 9x9'), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('7×7·9×9 탄도 보드 크기에 맞게 그려지고 최적 풀이로 클리어된다', (tester) async {
      for (final b in [BoardSize.seven, BoardSize.nine]) {
        final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
        await _openStage(tester, b.label);
        await tester.pump(const Duration(milliseconds: 2000));
        final s = container.read(gameProvider)!;
        expect(s.boardSize, b);
        expect(s.board.size, b.size);
        expect(find.byType(TileView), findsNWidgets(b.size * b.size));
        expect(find.text('${b.label} 1탄'), findsOneWidget);
        solve(container);
        expect(container.read(gameProvider)!.won, isTrue, reason: b.label);
        await toResult(tester);
        expect(find.text('다음 탄'), findsOneWidget);
        await _cleanup(tester);
      }
    });

    testWidgets('잠긴 탄은 눌러도 시작되지 않고, 게임 중 [목록]은 맵으로 돌아간다', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await tester.tap(find.text('클래식'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('5x5'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(StageMapScreen), findsOneWidget);
      // 3탄은 잠겨 있다 (숫자 대신 자물쇠)
      await tester.tap(find.byType(StageTile).at(2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(GameScreen), findsNothing);
      // 1탄 시작 후 [목록]
      await tester.tap(find.descendant(of: find.byType(StageTile), matching: find.text('1')).first);
      await tester.pump();
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(gameProvider)!.stageNumber, 1);
      await tester.tap(find.text('목록'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GameScreen), findsNothing);
      expect(find.byType(StageMapScreen), findsOneWidget);
      await _cleanup(tester);
    });

    testWidgets('일시정지 "처음부터": 클래식은 같은 탄, 러시는 새 도전', (tester) async {
      final container = await _pumpApp(tester, prefs: {'tutorialSeen': true});
      await _openStage(tester, '5x5');
      await tester.pump(const Duration(milliseconds: 2000));
      final ctrl = container.read(gameProvider.notifier);
      final first = container.read(gameProvider)!;
      final sol = Solver(first.target).solve(first.board)!;
      final (a, b) = sol.swaps.first;
      ctrl.swap(a, b);
      if (container.read(gameProvider)!.phase == Phase.playing) {
        ctrl.pause();
        ctrl.restart();
        await tester.pump(const Duration(milliseconds: 2000));
        final again = container.read(gameProvider)!;
        expect(again.board, first.board);
        expect(again.stageNumber, 1);
        expect(again.movesUsed, 0);
      }
      ctrl.start(GameMode.rush);
      await tester.pump(const Duration(milliseconds: 2000));
      final rushFirst = container.read(gameProvider)!.puzzle;
      ctrl.skip();
      await tester.pump(const Duration(milliseconds: 800));
      ctrl.restart();
      await tester.pump(const Duration(milliseconds: 2000));
      final r = container.read(gameProvider)!;
      expect(r.mode, GameMode.rush);
      expect(r.stage, 1);
      expect(identical(r.puzzle, rushFirst), isFalse);
      ctrl.quit();
      await _cleanup(tester);
    });
  });
}
