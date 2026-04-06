import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_model.dart';
import '../models/game_state.dart';

class BoardNotifier extends StateNotifier<BoardModel> {
  BoardNotifier() : super(BoardModel.empty());

  void generatePuzzle(Difficulty difficulty, SymmetryType symmetryType) {
    final steps = GameConfig.shuffleSteps[difficulty] ?? 10;
    state = BoardModel.generateSolvable(symmetryType, shuffleSteps: steps);
  }

  void swap(int r1, int c1, int r2, int c2) {
    state = state.swap(r1, c1, r2, c2);
  }

  void rotate() {
    state = state.rotate90CW();
  }
}

final boardProvider = StateNotifierProvider<BoardNotifier, BoardModel>(
  (ref) => BoardNotifier(),
);
