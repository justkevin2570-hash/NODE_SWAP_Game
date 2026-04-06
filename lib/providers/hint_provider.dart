import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'board_provider.dart';
import 'game_state_provider.dart';

typedef SwapPair = (int, int, int, int);

class HintNotifier extends StateNotifier<SwapPair?> {
  final Ref ref;

  HintNotifier(this.ref) : super(null);

  void computeHint() {
    final board = ref.read(boardProvider);
    final symmetryType = ref.read(gameStateProvider).targetSymmetry;

    SwapPair? bestSwap;
    int bestReduction = 0;
    final currentAsymmetry = board.asymmetryCount(symmetryType);

    for (final s in board.adjacentSwaps()) {
      final simulated = board.swap(s.$1, s.$2, s.$3, s.$4);
      final newAsymmetry = simulated.asymmetryCount(symmetryType);
      final reduction = currentAsymmetry - newAsymmetry;
      if (reduction > bestReduction) {
        bestReduction = reduction;
        bestSwap = s;
      }
    }

    state = bestSwap;
  }

  void clearHint() {
    state = null;
  }

  bool isHintTile(int r, int c) {
    final hint = state;
    if (hint == null) return false;
    return (r == hint.$1 && c == hint.$2) || (r == hint.$3 && c == hint.$4);
  }
}

final hintProvider = StateNotifierProvider<HintNotifier, SwapPair?>(
  (ref) => HintNotifier(ref),
);
