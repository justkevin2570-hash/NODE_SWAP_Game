import 'board.dart';
import 'generator.dart';
import 'rules.dart';
import 'stages_data.dart';
import 'symmetry.dart';

/// 클래식 [b] 크기의 [stage]탄(1~100) 퍼즐.
Puzzle stagePuzzle(BoardSize b, int stage) {
  final (code, target, par) = stageData[b]![stage - 1];
  return Puzzle(
    board: Board.parse(code),
    target: SymmetryType.values.byName(target),
    par: par,
    maxMoves: par + Rules.stageSlack(stage),
  );
}
