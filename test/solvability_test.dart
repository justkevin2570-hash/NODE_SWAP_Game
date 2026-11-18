import 'dart:collection';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/game_state.dart';
import 'package:node_swap_game/game/logic/board.dart';
import 'package:node_swap_game/game/logic/generator.dart';
import 'package:node_swap_game/game/logic/lessons.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 회전(0~3번) 중 하나라도 목표 대칭이면 "회전만으로 완성 가능".
/// solver 의 "좌우↔상하" 같은 가정을 쓰지 않는 독립적인 판정.
bool _solvedUpToRotation(Board b, SymmetryType t) {
  var x = b;
  for (int k = 0; k < 4; k++) {
    if (x.isSymmetric(t)) return true;
    x = x.rotateCW();
  }
  return false;
}

/// 휴리스틱 없이 BFS 로 구한 최소 swap 수 (maxDepth 를 넘으면 null).
int? _bruteForceMinSwaps(Board start, SymmetryType t, int maxDepth) {
  if (_solvedUpToRotation(start, t)) return 0;
  final seen = <int>{start.bits};
  var frontier = Queue<Board>()..add(start);
  for (int depth = 1; depth <= maxDepth; depth++) {
    final next = Queue<Board>();
    for (final b in frontier) {
      for (final (a, c) in Board.adjacentPairs) {
        if (b[a] == b[c]) continue;
        final n = b.swap(a, c);
        if (!seen.add(n.bits)) continue;
        if (_solvedUpToRotation(n, t)) return depth;
        next.add(n);
      }
    }
    frontier = next;
  }
  return null;
}

/// solver 풀이를 실제로 적용해 목표 대칭이 되는지 (회전 포함) 확인.
bool _replay(Puzzle p, Solution s) {
  var b = p.board;
  for (final (a, c) in s.swaps) {
    if (!Board.isAdjacent(a, c) || b[a] == b[c]) return false;
    b = b.swap(a, c);
  }
  if (s.needsRotation) b = b.rotateCW();
  return b.isSymmetric(p.target);
}

/// 스펙 × 대칭 종류마다 몇 판씩 검사할지. 기본은 빠르게, 전수에 가깝게 보려면
/// `flutter test test/solvability_test.dart --dart-define=PUZZLE_SAMPLES=60` (약 3분, 9천여 판).
const _samples = int.fromEnvironment('PUZZLE_SAMPLES', defaultValue: 8);

void main() {
  group('생성되는 모든 퍼즐은 풀 수 있다', () {
    final specs = <String, PuzzleSpec>{
      for (int stage = 1; stage <= 30; stage++) '러시 $stage스테이지': Rules.rushSpec(stage),
      for (final d in Difficulty.values) '클래식 ${d.label}': Rules.classicSpec(d),
    };

    test('스펙 × 대칭 종류 × $_samples판: 최소 이동 ≤ 허용 이동, 풀이 재생 성공', () {
      final rng = Random(20261117);
      final gen = PuzzleGenerator(rng);
      var total = 0;
      final parHistogram = <int, int>{};
      final slackHistogram = <int, int>{};
      for (final entry in specs.entries) {
        for (final type in entry.value.types) {
          for (int k = 0; k < _samples; k++) {
            final p = gen.generate(entry.value, forcedType: type);
            total++;
            final reason = '${entry.key} ${type.label} #$k\n${p.board}';
            // 시작하자마자 (회전만으로) 풀려 있으면 안 된다
            expect(_solvedUpToRotation(p.board, p.target), isFalse, reason: reason);
            final s = Solver(p.target).solve(p.board, maxDepth: p.maxMoves);
            expect(s, isNotNull, reason: '풀이 없음: $reason');
            expect(s!.moveCount, p.par, reason: reason);
            expect(p.par, lessThanOrEqualTo(p.maxMoves), reason: reason);
            expect(_replay(p, s), isTrue, reason: '풀이 재생 실패: $reason');
            parHistogram[p.par] = (parHistogram[p.par] ?? 0) + 1;
            slackHistogram[p.maxMoves - p.par] = (slackHistogram[p.maxMoves - p.par] ?? 0) + 1;
          }
        }
      }
      // ignore: avoid_print
      print('검사한 퍼즐 $total판 · 최소 이동 분포 ${Map.fromEntries(parHistogram.entries.toList()..sort((a, b) => a.key - b.key))}'
          ' · 여유 이동 분포 $slackHistogram');
    });

    test('독립 검증: 휴리스틱 없는 BFS 로 구한 최소 이동 = solver 의 최소 이동', () {
      final rng = Random(7);
      final gen = PuzzleGenerator(rng);
      var checked = 0;
      for (int stage = 1; stage <= 12; stage++) {
        final spec = Rules.rushSpec(stage);
        for (final type in spec.types) {
          for (int k = 0; k < 6; k++) {
            final p = gen.generate(spec, forcedType: type);
            if (p.par > 4) continue; // BFS 가 감당할 수 있는 깊이까지만
            final brute = _bruteForceMinSwaps(p.board, p.target, 4);
            expect(brute, p.par, reason: '스테이지 $stage ${type.label}\n${p.board}');
            checked++;
          }
        }
      }
      // ignore: avoid_print
      print('BFS 로 교차 검증한 퍼즐 $checked판');
      expect(checked, greaterThan(100));
    });

    test('튜토리얼 보드도 모두 풀린다', () {
      for (final l in lessons) {
        final s = Solver(l.target).solve(l.board, maxDepth: 3);
        expect(s, isNotNull, reason: l.title);
        var b = l.board;
        for (final (a, c) in s!.swaps) {
          b = b.swap(a, c);
        }
        if (s.needsRotation) b = b.rotateCW();
        expect(b.isSymmetric(l.target), isTrue, reason: l.title);
      }
    });
  });

  group('실제 게임 규칙으로 끝까지 플레이', () {
    Future<ProviderContainer> makeContainer() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        prefsProvider.overrideWithValue(prefs),
        audioProvider.overrideWithValue(AudioEngine.silent()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    /// 지금 퍼즐을 최적 풀이대로 실제 컨트롤러에 입력한다.
    void playOptimal(GameController ctrl, GameSession s) {
      final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
      for (final (a, b) in sol.swaps) {
        ctrl.swap(a, b);
      }
      if (sol.needsRotation) ctrl.rotate();
    }

    testWidgets('클래식: 난이도별 100판씩 모두 클리어 (별 3개)', (tester) async {
      final container = await makeContainer();
      final ctrl = container.read(gameProvider.notifier);
      for (final d in Difficulty.values) {
        for (int i = 0; i < 100; i++) {
          ctrl.start(GameMode.classic, difficulty: d);
          await tester.pump(const Duration(milliseconds: 1900)); // 카운트다운
          final s = container.read(gameProvider)!;
          expect(s.phase, Phase.playing);
          playOptimal(ctrl, s);
          final done = container.read(gameProvider)!;
          expect(done.won, isTrue, reason: '${d.label} #$i 클리어 실패\n${s.board}\n${s.target.label}');
          expect(done.stars, 3);
        }
      }
      ctrl.quit();
    });

    testWidgets('러시: 30스테이지까지 연속 클리어를 5번 (막힘 판정이 잘못 뜨지 않는지)', (tester) async {
      final container = await makeContainer();
      final ctrl = container.read(gameProvider.notifier);
      final seenTypes = <SymmetryType>{};
      for (int run = 0; run < 5; run++) {
        ctrl.start(GameMode.rush);
        await tester.pump(const Duration(milliseconds: 1900));
        for (int stage = 1; stage <= 30; stage++) {
          final s = container.read(gameProvider)!;
          expect(s.phase, Phase.playing, reason: 'run $run stage $stage');
          expect(s.stage, stage);
          seenTypes.add(s.target);
          playOptimal(ctrl, s);
          final after = container.read(gameProvider)!;
          expect(after.cleared, stage, reason: 'run $run stage $stage 클리어 실패\n${s.board}\n${s.target.label}');
          await tester.pump(const Duration(milliseconds: 800)); // 다음 퍼즐로 전환
        }
      }
      expect(seenTypes, SymmetryType.values.toSet());
      ctrl.quit();
    });

    testWidgets('이동을 다 쓴 뒤에도 회전만 남았다면 실패가 아니다', (tester) async {
      final container = await makeContainer();
      final ctrl = container.read(gameProvider.notifier);
      var checked = 0;
      for (int i = 0; i < 300 && checked < 20; i++) {
        ctrl.start(GameMode.classic, difficulty: Difficulty.hard); // 여유 0 → 마지막 수로 이동을 다 씀
        await tester.pump(const Duration(milliseconds: 1900));
        final s = container.read(gameProvider)!;
        final sol = Solver(s.target).solve(s.board, maxDepth: s.movesLeft)!;
        if (!sol.needsRotation) continue;
        for (final (a, b) in sol.swaps) {
          ctrl.swap(a, b);
        }
        final mid = container.read(gameProvider)!;
        expect(mid.movesLeft, 0);
        expect(mid.phase, Phase.playing, reason: '회전만 하면 되는데 실패 처리됨');
        expect(mid.rotateToWin, isTrue);
        ctrl.rotate();
        expect(container.read(gameProvider)!.won, isTrue);
        checked++;
      }
      expect(checked, greaterThan(0));
      ctrl.quit();
    });
  });
}
