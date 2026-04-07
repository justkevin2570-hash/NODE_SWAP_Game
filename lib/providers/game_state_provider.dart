import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_model.dart';
import '../models/game_state.dart';
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
  DateTime? _lastSwapTime;
  bool _suppressWinCheck = false; // 회전 애니메이션 중 win 체크 억제

  GameStateNotifier(this.ref) : super(GameState.initial()) {
    // 보드 변화 감지 → 승패 판정
    ref.listen<BoardModel>(boardProvider, (_, board) {
      if (state.phase != GamePhase.playing) return;
      if (_suppressWinCheck) return; // 회전 중이면 스킵
      if (board.checkSymmetry(state.targetSymmetry)) {
        final timeTaken =
            GameConfig.timeLimitSecs[state.difficulty]! - state.timeRemaining;
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
        final timeTaken = GameConfig.timeLimitSecs[state.difficulty]!;
        state = state.copyWith(
          phase: GamePhase.lost,
          timeTaken: timeTaken,
          clearSelection: true,
        );
        ref.read(soundProvider.notifier).play(SoundEvent.lose);
      }
    });
  }

  void startGame(Difficulty difficulty, SymmetryType symmetryType) {
    final moves = GameConfig.maxMoves[difficulty]!;
    final hints = GameConfig.hintCount[difficulty]!;
    final timeLimit = GameConfig.timeLimitSecs[difficulty]!;
    _lastSwapTime = null;
    state = GameState(
      moveCount: 0,
      maxMoves: moves,
      hintsRemaining: hints,
      difficulty: difficulty,
      phase: GamePhase.playing,
      targetSymmetry: symmetryType,
      timeRemaining: timeLimit,
    );
    ref.read(boardProvider.notifier).generatePuzzle(difficulty, symmetryType);
    ref.read(gameTimerProvider.notifier).start(timeLimit);
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
      // 스왑 애니메이션 이벤트 발행
      ref.read(swapAnimationProvider.notifier).state = (r1, c1, row, col);
      ref.read(boardProvider.notifier).swap(r1, c1, row, col);
      final newMoveCount = state.moveCount + 1;
      state = state.copyWith(
        moveCount: newMoveCount,
        clearSelection: true,
      );
      _evaluateCombo();
      ref.read(soundProvider.notifier).play(SoundEvent.swap);
      // 이동 횟수 소진 → 게임 오버 (win 판정은 boardProvider 리스너에서 먼저 처리됨)
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

  void _evaluateCombo() {
    final now = DateTime.now();
    int newCombo;
    if (_lastSwapTime != null &&
        now.difference(_lastSwapTime!).inMilliseconds <= 3000) {
      newCombo = state.comboCount + 1;
      final newMax = max(newCombo, state.maxCombo);
      state = state.copyWith(comboCount: newCombo, maxCombo: newMax);
      if (newCombo >= 2) {
        final event =
            newCombo >= 5 ? SoundEvent.comboMax : SoundEvent.combo;
        ref.read(soundProvider.notifier).play(event);
      }
    } else {
      newCombo = 1;
      state = state.copyWith(comboCount: 1);
    }
    _lastSwapTime = now;
    _addScore(newCombo);
  }

  void _addScore(int combo) {
    const base = 100;
    final timeBonus = state.timeRemaining * 2;
    final multiplier = 1.0 + (combo - 1) * 0.5;
    final gained = ((base + timeBonus) * multiplier).round();
    state = state.copyWith(score: state.score + gained);
  }

  void rotateBoard() {
    if (state.phase != GamePhase.playing) return;
    _suppressWinCheck = true; // 회전 애니메이션 시작 — win 체크 억제
    state = state.copyWith(clearSelection: true);
  }

  /// 회전 애니메이션 완료 후 호출 — win 체크 재개 및 판정
  void onRotationComplete() {
    _suppressWinCheck = false;
    if (state.phase != GamePhase.playing) return;
    final board = ref.read(boardProvider);
    if (board.checkSymmetry(state.targetSymmetry)) {
      final timeTaken =
          GameConfig.timeLimitSecs[state.difficulty]! - state.timeRemaining;
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
  }

  void useHint() {
    if (!state.canHint) return;
    state = state.copyWith(hintsRemaining: state.hintsRemaining - 1);
  }

  void resetGame() {
    startGame(state.difficulty, state.targetSymmetry);
  }
}

final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(ref),
);
