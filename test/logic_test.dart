import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/game/logic/board.dart';
import 'package:node_swap_game/game/logic/generator.dart';
import 'package:node_swap_game/game/logic/lessons.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/game/logic/symmetry.dart';

Board _applyAll(Board b, Solution s) {
  var out = b;
  for (final (x, y) in s.swaps) {
    expect(Board.isAdjacent(x, y), isTrue);
    out = out.swap(x, y);
  }
  if (s.needsRotation) out = out.rotateCW();
  return out;
}

void main() {
  group('Board', () {
    final b = Board.fromRows(const [
      [1, 0, 0, 0, 1],
      [0, 1, 0, 1, 0],
      [0, 0, 1, 0, 0],
      [0, 1, 0, 1, 0],
      [1, 0, 0, 0, 1],
    ]);

    test('대칭 판정', () {
      for (final t in SymmetryType.values) {
        expect(b.isSymmetric(t), isTrue, reason: t.name);
      }
      final broken = b.swap(0, 1);
      expect(broken.isSymmetric(SymmetryType.horizontal), isFalse);
      expect(broken.mismatchCount(SymmetryType.horizontal), 2);
    });

    test('회전 4번이면 제자리, 상하 대칭 → 좌우 대칭', () {
      final v = Board.fromRows(const [
        [1, 1, 0, 0, 0],
        [0, 0, 0, 1, 1],
        [1, 0, 1, 0, 0],
        [0, 0, 0, 1, 1],
        [1, 1, 0, 0, 0],
      ]);
      expect(v.isSymmetric(SymmetryType.vertical), isTrue);
      expect(v.isSymmetric(SymmetryType.horizontal), isFalse);
      expect(v.rotateCW().isSymmetric(SymmetryType.horizontal), isTrue);
      expect(v.rotateCW().rotateCW().rotateCW().rotateCW(), v);
    });

    test('rotatedIndex 와 rotateCW 일치', () {
      final one = Board(1 << 1); // (0,1)
      expect(one.rotateCW()[Board.rotatedIndex(1)], 1);
      expect(Board.rotatedIndex(1), 1 * 5 + 4); // (1,4)
    });

    test('인접 쌍은 40개', () {
      expect(Board.adjacentPairs.length, 40);
      for (final (a, c) in Board.adjacentPairs) {
        expect(Board.isAdjacent(a, c), isTrue);
      }
    });
  });

  group('Solver', () {
    test('한 수짜리 퍼즐', () {
      final sym = Board.fromRows(const [
        [1, 0, 0, 0, 1],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
      ]);
      final b = sym.swap(0, 5);
      final s = Solver(SymmetryType.horizontal).solve(b)!;
      expect(s.moveCount, 1);
      expect(_applyAll(b, s).isSymmetric(SymmetryType.horizontal), isTrue);
    });

    test('상하 대칭 보드는 0수 + 회전', () {
      final v = Board.fromRows(const [
        [1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0],
        [1, 1, 0, 0, 0],
      ]);
      final s = Solver(SymmetryType.horizontal).solve(v)!;
      expect(s.moveCount, 0);
      expect(s.needsRotation, isTrue);
    });
  });

  group('Generator', () {
    test('모든 퍼즐은 허용 이동 수 안에 풀린다', () {
      final gen = PuzzleGenerator(Random(42));
      final sw = Stopwatch()..start();
      for (int stage = 1; stage <= 26; stage += 1) {
        for (int k = 0; k < 6; k++) {
          final p = gen.generate(Rules.rushSpec(stage));
          expect(p.par, greaterThanOrEqualTo(1));
          expect(p.par, lessThanOrEqualTo(p.maxMoves));
          final s = Solver(p.target).solve(p.board)!;
          expect(s.moveCount, p.par);
          expect(_applyAll(p.board, s).isSymmetric(p.target), isTrue);
          // 시작 상태에서 바로 풀려 있으면 안 된다.
          expect(p.board.isSymmetric(p.target), isFalse);
          expect(p.board.isSymmetric(p.target.rotated), isFalse);
        }
      }
      // ignore: avoid_print
      print('generated 156 puzzles in ${sw.elapsedMilliseconds}ms');
    });

    test('클래식 난이도별 생성', () {
      final gen = PuzzleGenerator(Random(7));
      for (final d in Difficulty.values) {
        for (int k = 0; k < 10; k++) {
          final p = gen.generate(Rules.classicSpec(d));
          expect(p.maxMoves - p.par, Rules.classicSpec(d).slack);
        }
      }
    });
  });

  group('Rules', () {
    test('콤보 배율은 최대 3배, 피버는 2배', () {
      expect(Rules.comboMultiplier(1), 1.0);
      expect(Rules.comboMultiplier(5), 2.0);
      expect(Rules.comboMultiplier(50), 3.0);
      expect(Rules.comboMultiplier(1, fever: true), 2.0);
    });

    test('별점', () {
      expect(Rules.classicStars(movesUsed: 3, par: 3), 3);
      expect(Rules.classicStars(movesUsed: 4, par: 3), 2);
      expect(Rules.classicStars(movesUsed: 6, par: 3), 1);
    });
  });

  test('튜토리얼 보드는 의도대로 풀린다', () {
    final s1 = Solver(lessons[0].target).solve(lessons[0].board)!;
    expect(s1.moveCount, 1);
    expect(s1.needsRotation, isFalse);
    final s2 = Solver(lessons[1].target).solve(lessons[1].board)!;
    expect(s2.moveCount, 0);
    expect(s2.needsRotation, isTrue);
    final s3 = Solver(lessons[2].target).solve(lessons[2].board)!;
    expect(s3.moveCount, 1);
  });
}
