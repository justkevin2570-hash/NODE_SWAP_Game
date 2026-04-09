import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_model.dart';
import '../models/game_state.dart';
import '../models/level_config.dart';
import 'board_provider.dart';
import 'timer_provider.dart';
import 'sound_provider.dart';

final symmetryProvider = StateProvider<SymmetryType>(
  (ref) => SymmetryType.horizontal,
);

// 스왑 애니메이션 이벤트: (r1, c1, r2, c2)
final swapAnimationProvider = StateProvider<(int, int, int, int)?>((_) => null);

class GameStateNotifier extends StateNotifier<GameState> {
  final Ref ref;
  bool _suppressWinCheck = false;
  LevelConfig? _currentConfig;

  GameStateNotifier(this.ref) : super(GameState.initial()) {
    // 보드 변화 감지 → 승패 판정
    ref.listen<BoardModel>(boardProvider, (_, board) {
      if (state.phase != GamePhase.playing) return;
      if (_suppressWinCheck) return;
      if (board.checkSymmetry(state.targetSymmetry)) {
        final timeTaken = state.timeLimitSecs - state.timeRemaining;
        final movesLeft = state.maxMoves - state.moveCount;
        final finalBonus = movesLeft * 50;
        ref.read(gameTimerProvider.notifier).pause();
        state = state.copyWith(
          phase: GamePhase.won,
          timeTaken: timeTaken,
          score: state.score + finalBonus,
          clearSelection: true,
        );
        ref.read(soundProvider.notifier).play(SoundEvent.win);
      }
    });

    // 타이머 리스너
    ref.listen<int>(gameTimerProvider, (_, secs) {
      if (state.phase != GamePhase.playing) return;
      state = state.copyWith(timeRemaining: secs);
      if (secs == 0) {
        final timeTaken = state.timeLimitSecs;
        state = state.copyWith(
          phase: GamePhase.lost,
          timeTaken: timeTaken,
          clearSelection: true,
        );
        ref.read(soundProvider.notifier).play(SoundEvent.lose);
      }
    });
  }

  void startGame(LevelConfig config) {
    _currentConfig = config;
    state = GameState(
      moveCount: 0,
      maxMoves: config.maxMoves,
      hintsRemaining: config.hintCount,
      difficulty: Difficulty.easy, // LevelConfig 기반으로 동작하므로 값은 무관
      phase: GamePhase.playing,
      targetSymmetry: config.symmetryType,
      timeRemaining: config.timeLimitSecs,
      timeLimitSecs: config.timeLimitSecs,
    );
    ref.read(boardProvider.notifier).generatePuzzle(config);
    ref.read(gameTimerProvider.notifier).start(config.timeLimitSecs);
  }

  void selectTile(int row, int col) {
    if (state.phase != GamePhase.playing) return;

    if (!state.isSelected) {
      state = state.copyWith(selectedRow: row, selectedCol: col);
      ref.read(soundProvider.notifier).play(SoundEvent.tap);
      return;
    }

    final r1 = state.selectedRow!;
    final c1 = state.selectedCol!;

    if (r1 == row && c1 == col) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    final board = ref.read(boardProvider);
    if (board.isAdjacent(r1, c1, row, col)) {
      if (!state.canMove) return;
      ref.read(swapAnimationProvider.notifier).state = (r1, c1, row, col);
      ref.read(boardProvider.notifier).swap(r1, c1, row, col);
      final newMoveCount = state.moveCount + 1;
      state = state.copyWith(
        moveCount: newMoveCount,
        clearSelection: true,
      );
      _addScore();
      ref.read(soundProvider.notifier).play(SoundEvent.swap);
      if (state.phase == GamePhase.playing && newMoveCount >= state.maxMoves) {
        ref.read(gameTimerProvider.notifier).pause();
        state = state.copyWith(phase: GamePhase.lost, clearSelection: true);
        ref.read(soundProvider.notifier).play(SoundEvent.lose);
      }
    } else {
      state = state.copyWith(selectedRow: row, selectedCol: col);
      ref.read(soundProvider.notifier).play(SoundEvent.tap);
    }
  }

  void _addScore() {
    const base = 100;
    final timeBonus = state.timeRemaining * 2;
    final gained = base + timeBonus;
    state = state.copyWith(score: state.score + gained);
  }

  void rotateBoard() {
    if (state.phase != GamePhase.playing) return;
    if (!state.canMove) return;
    _suppressWinCheck = true;
    final newMoveCount = state.moveCount + 1;
    state = state.copyWith(moveCount: newMoveCount, clearSelection: true);
    _addScore();
    if (newMoveCount >= state.maxMoves) {
      // 이동 초과 판정은 onRotationComplete에서 (회전 후 대칭 체크 우선)
    }
  }

  void onRotationComplete() {
    _suppressWinCheck = false;
    if (state.phase != GamePhase.playing) return;
    final board = ref.read(boardProvider);
    if (board.checkSymmetry(state.targetSymmetry)) {
      final timeTaken = state.timeLimitSecs - state.timeRemaining;
      final movesLeft = state.maxMoves - state.moveCount;
      final finalBonus = movesLeft * 50;
      ref.read(gameTimerProvider.notifier).pause();
      state = state.copyWith(
        phase: GamePhase.won,
        timeTaken: timeTaken,
        score: state.score + finalBonus,
        clearSelection: true,
      );
      ref.read(soundProvider.notifier).play(SoundEvent.win);
    } else if (state.moveCount >= state.maxMoves) {
      ref.read(gameTimerProvider.notifier).pause();
      state = state.copyWith(phase: GamePhase.lost, clearSelection: true);
      ref.read(soundProvider.notifier).play(SoundEvent.lose);
    }
  }

  void useHint() {
    if (!state.canHint) return;
    state = state.copyWith(hintsRemaining: state.hintsRemaining - 1);
  }

  void resetGame() {
    if (_currentConfig != null) {
      startGame(_currentConfig!);
    }
  }
}

final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(ref),
);
