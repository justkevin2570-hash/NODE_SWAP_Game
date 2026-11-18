import 'dart:isolate';
import 'dart:math';

import 'board.dart';
import 'solver.dart';
import 'symmetry.dart';

/// 한 판의 퍼즐.
class Puzzle {
  const Puzzle({
    required this.board,
    required this.target,
    required this.par,
    required this.maxMoves,
  });

  final Board board;
  final SymmetryType target;

  /// 최소 이동 수 (solver 로 계산된 정확한 값).
  final int par;

  /// 허용 이동 수 (par + 여유).
  final int maxMoves;
}

/// 퍼즐 생성 규칙.
class PuzzleSpec {
  const PuzzleSpec({
    required this.scrambleSwaps,
    required this.slack,
    required this.types,
  });

  /// 대칭 보드를 섞을 때 쓰는 swap 횟수 (+ 회전 1회).
  final int scrambleSwaps;

  /// 최소 이동 수에 더해 줄 여유 이동 수.
  final int slack;

  /// 나올 수 있는 대칭 종류.
  final List<SymmetryType> types;
}

/// 대칭 보드를 만든 뒤 거꾸로 섞어서 퍼즐을 만든다.
/// 최소 이동 수를 solver 로 정확히 계산하므로 항상 풀 수 있다.
class PuzzleGenerator {
  PuzzleGenerator([Random? random]) : _rng = random ?? Random();

  final Random _rng;

  Puzzle generate(PuzzleSpec spec, {SymmetryType? forcedType}) {
    final type = forcedType ?? spec.types[_rng.nextInt(spec.types.length)];
    final solver = Solver(type);
    final wantedPar = max(1, spec.scrambleSwaps - 1);

    Puzzle? fallback;
    for (int attempt = 0; attempt < 40; attempt++) {
      final scrambled = _scramble(_symmetricBoard(type), spec.scrambleSwaps);
      final solution = solver.solve(scrambled, maxDepth: spec.scrambleSwaps);
      if (solution == null || solution.moveCount == 0) continue;
      final puzzle = Puzzle(
        board: scrambled,
        target: type,
        par: solution.moveCount,
        maxMoves: solution.moveCount + spec.slack,
      );
      if (solution.moveCount >= wantedPar) return puzzle;
      if (fallback == null || puzzle.par > fallback.par) fallback = puzzle;
    }
    // 원하는 난이도를 못 맞춰도 풀 수 있는 퍼즐은 반드시 돌려준다.
    return fallback ?? _trivialPuzzle(type, spec.slack);
  }

  /// 완성된 대칭 보드 (타이틀 화면 데모 등에 사용).
  Board symmetricBoard(SymmetryType type) => _symmetricBoard(type);

  Board _symmetricBoard(SymmetryType type) {
    while (true) {
      var bits = 0;
      for (int i = 0; i < Board.cellCount; i++) {
        final p = type.partnerOf(i);
        if (p < i) continue;
        if (_rng.nextBool()) bits |= (1 << i) | (1 << p);
      }
      final ones = _popCount(bits);
      // 너무 한쪽 색으로 쏠린 보드는 섞어도 재미가 없다.
      if (ones >= 8 && ones <= 17) return Board(bits);
    }
  }

  Board _scramble(Board board, int swaps) {
    var b = board;
    final rotateAt = _rng.nextInt(swaps + 1);
    int? last;
    for (int step = 0; step <= swaps; step++) {
      if (step == rotateAt) {
        b = b.rotateCW();
        last = null;
        continue;
      }
      // 값이 다른 칸끼리만 섞어야 실제로 보드가 바뀐다.
      final candidates = <int>[
        for (int i = 0; i < Board.adjacentPairs.length; i++)
          if (i != last &&
              b[Board.adjacentPairs[i].$1] != b[Board.adjacentPairs[i].$2])
            i,
      ];
      if (candidates.isEmpty) continue;
      final pick = candidates[_rng.nextInt(candidates.length)];
      final (x, y) = Board.adjacentPairs[pick];
      b = b.swap(x, y);
      last = pick;
    }
    return b;
  }

  Puzzle _trivialPuzzle(SymmetryType type, int slack) {
    // 대칭 보드에서 한 칸만 어긋나게 만든다 (최소 1수).
    while (true) {
      final base = _symmetricBoard(type);
      for (final (a, c) in Board.adjacentPairs) {
        final b = base.swap(a, c);
        final s = Solver(type).solve(b, maxDepth: 2);
        if (s != null && s.moveCount == 1) {
          return Puzzle(board: b, target: type, par: 1, maxMoves: 1 + slack);
        }
      }
    }
  }

  static int _popCount(int v) {
    var n = 0;
    while (v != 0) {
      v &= v - 1;
      n++;
    }
    return n;
  }
}

/// 다른 isolate 에서 퍼즐을 만든다 (UI 스레드를 막지 않음).
/// 최상위 함수라서 isolate 로 넘기는 클로저가 spec 외에는 아무것도 붙잡지 않는다.
Future<Puzzle> generatePuzzleInIsolate(PuzzleSpec spec) =>
    Isolate.run(() => PuzzleGenerator().generate(spec));
