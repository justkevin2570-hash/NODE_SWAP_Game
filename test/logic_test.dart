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
    expect(b.isAdjacent(x, y), isTrue);
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
      expect(one.rotateCW()[one.grid.rotatedIndex(1)], 1);
      expect(one.grid.rotatedIndex(1), 1 * 5 + 4); // (1,4)
    });

    test('대각선 대칭: y=−x 는 전치, y=x 는 반대 대각선, 회전하면 서로 바뀐다', () {
      final down = Board.fromRows(const [
        [1, 0, 1, 1, 0],
        [0, 1, 0, 0, 1],
        [1, 0, 0, 1, 0],
        [1, 0, 1, 1, 1],
        [0, 1, 0, 1, 0],
      ]);
      expect(down.isSymmetric(SymmetryType.diagonalDown), isTrue);
      expect(down.isSymmetric(SymmetryType.diagonalUp), isFalse);
      // 시계방향 90° 회전하면 ↘ 대칭이 ↗ 대칭이 된다
      expect(down.rotateCW().isSymmetric(SymmetryType.diagonalUp), isTrue);
      expect(down.rotateCW().rotateCW().isSymmetric(SymmetryType.diagonalDown), isTrue);
      // 대각선 위 5칸은 자기 자신과 짝, 나머지 20칸은 10쌍
      final g = down.grid;
      for (final t in [SymmetryType.diagonalUp, SymmetryType.diagonalDown]) {
        expect(g.pairs(t).length, 10);
        expect(t.rotated.rotated, t);
      }
      expect(g.partnerOf(SymmetryType.diagonalDown, 1), 5); // (0,1) ↔ (1,0)
      expect(g.partnerOf(SymmetryType.diagonalUp, 0), 24); // (0,0) ↔ (4,4)
      expect(g.partnerOf(SymmetryType.diagonalUp, 4), 4); // (0,4) 는 ↗ 대각선 위
    });

    test('인접 쌍은 5×5 40개, 7×7 84개, 9×9 144개', () {
      for (final (n, count) in [(5, 40), (7, 84), (9, 144)]) {
        final g = Grid.of(n);
        expect(g.adjacentPairs.length, count);
        for (final (a, c) in g.adjacentPairs) {
          expect(g.isAdjacent(a, c), isTrue);
        }
      }
      expect(Grid.of(9).isAdjacent(8, 9), isFalse); // 줄 끝과 다음 줄 처음은 이웃이 아니다
    });

    test('큰 판: 축 위 칸 수, 회전, 문자열 변환', () {
      for (final n in [7, 9]) {
        final g = Grid.of(n);
        for (final t in SymmetryType.values) {
          final onAxis = [for (int i = 0; i < g.cellCount; i++) if (g.partnerOf(t, i) == i) i].length;
          expect(onAxis, t == SymmetryType.point ? 1 : n, reason: '$n ${t.name}');
          expect(g.pairs(t).length, (g.cellCount - onAxis) ~/ 2);
        }
        final b = PuzzleGenerator(Random(n)).symmetricBoard(SymmetryType.diagonalUp, size: n);
        expect(b.size, n);
        expect(b.isSymmetric(SymmetryType.diagonalUp), isTrue);
        expect(b.rotateCW().isSymmetric(SymmetryType.diagonalDown), isTrue);
        expect(b.rotateCW().rotateCW().rotateCW().rotateCW(), b);
        expect(Board.parse(b.code), b);
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

    test('isolate 에서도 퍼즐을 만들 수 있다 (러시 미리 만들기용)', () async {
      final p = await generatePuzzleInIsolate(Rules.rushSpec(21));
      final s = Solver(p.target).solve(p.board, maxDepth: p.maxMoves)!;
      expect(s.moveCount, p.par);
    });

    test('7×7·9×9 퍼즐도 만들고 풀 수 있다', () {
      final gen = PuzzleGenerator(Random(7));
      for (final n in [7, 9]) {
        for (final t in SymmetryType.values) {
          final p = gen.generate(PuzzleSpec(scrambleSwaps: 5, slack: 1, types: [t], size: n), forcedType: t);
          expect(p.board.size, n);
          final s = Solver(t).solve(p.board, maxDepth: p.maxMoves)!;
          expect(s.moveCount, p.par);
          expect(_applyAll(p.board, s).isSymmetric(t), isTrue);
        }
      }
    });

    test('탐색량 제한: 다 못 따져 보면 gaveUp', () {
      final p = PuzzleGenerator(Random(3))
          .generate(const PuzzleSpec(scrambleSwaps: 8, slack: 0, types: [SymmetryType.horizontal], size: 9));
      final solver = Solver(p.target);
      expect(solver.solve(p.board, maxDepth: p.par, maxNodes: 3), isNull);
      expect(solver.gaveUp, isTrue);
      expect(solver.solve(p.board, maxDepth: p.par)!.moveCount, p.par);
      expect(solver.gaveUp, isFalse);
    });
  });

  group('Rules', () {
    test('대각선 대칭은 6스테이지부터 나온다', () {
      for (int stage = 1; stage <= 5; stage++) {
        expect(Rules.rushSpec(stage).types.any((t) => t.isDiagonal), isFalse);
      }
      expect(Rules.rushSpec(6).types, containsAll([SymmetryType.diagonalUp, SymmetryType.diagonalDown]));
      expect(Rules.stageCurve(BoardSize.nine, 100).types.length, 5);
    });

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
    final s4 = Solver(lessons[3].target).solve(lessons[3].board)!;
    expect(s4.moveCount, 1);
    expect(s4.needsRotation, isFalse);
  });
}
