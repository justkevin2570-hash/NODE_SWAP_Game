import 'board.dart';
import 'generator.dart';
import 'rules.dart';
import 'stages_data.dart';
import 'symmetry.dart';

/// 클래식 [d] 난이도의 [stage]탄(1~100) 퍼즐.
Puzzle stagePuzzle(Difficulty d, int stage) {
  final (bits, target, par) = stageData[d]![stage - 1];
  return Puzzle(
    board: Board(bits),
    target: SymmetryType.values.byName(target),
    par: par,
    maxMoves: par + Rules.classicSpec(d).slack,
  );
}
