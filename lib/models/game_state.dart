import 'board_model.dart';

enum Difficulty { easy, normal, hard }

enum GamePhase { playing, won, lost }

class GameState {
  final int moveCount;
  final int maxMoves;
  final int hintsRemaining;
  final Difficulty difficulty;
  final GamePhase phase;
  final SymmetryType targetSymmetry;
  final int? selectedRow;
  final int? selectedCol;
  final int timeRemaining;
  final int timeLimitSecs; // 레벨 초기 제한시간 (timeTaken 계산용)
  final int timeTaken;
  final int score;

  const GameState({
    required this.moveCount,
    required this.maxMoves,
    required this.hintsRemaining,
    required this.difficulty,
    required this.phase,
    required this.targetSymmetry,
    this.selectedRow,
    this.selectedCol,
    this.timeRemaining = 90,
    this.timeLimitSecs = 90,
    this.timeTaken = 0,
    this.score = 0,
  });

  factory GameState.initial() {
    return const GameState(
      moveCount: 0,
      maxMoves: 20,
      hintsRemaining: 3,
      difficulty: Difficulty.easy,
      phase: GamePhase.playing,
      targetSymmetry: SymmetryType.horizontal,
      timeRemaining: 90,
      timeLimitSecs: 90,
    );
  }

  bool get isSelected => selectedRow != null && selectedCol != null;
  bool get canMove => moveCount < maxMoves && phase == GamePhase.playing;
  bool get canHint => hintsRemaining > 0 && phase == GamePhase.playing;
  bool get isTimeCritical => timeRemaining <= 10;
  int get comboCount => 0; // 콤보 시스템 미구현 - 항상 0

  int get starRating {
    if (phase != GamePhase.won) return 0;
    if (moveCount <= maxMoves * 0.5) return 3;
    if (moveCount <= maxMoves * 0.8) return 2;
    return 1;
  }

  // 이동 횟수 대비 남은 여유 (0.0 ~ 1.0, 1이 가득 찬 상태)
  double get moveProgress => moveCount / maxMoves;

  GameState copyWith({
    int? moveCount,
    int? maxMoves,
    int? hintsRemaining,
    Difficulty? difficulty,
    GamePhase? phase,
    SymmetryType? targetSymmetry,
    int? selectedRow,
    int? selectedCol,
    bool clearSelection = false,
    int? timeRemaining,
    int? timeLimitSecs,
    int? timeTaken,
    int? score,
  }) {
    return GameState(
      moveCount: moveCount ?? this.moveCount,
      maxMoves: maxMoves ?? this.maxMoves,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
      difficulty: difficulty ?? this.difficulty,
      phase: phase ?? this.phase,
      targetSymmetry: targetSymmetry ?? this.targetSymmetry,
      selectedRow: clearSelection ? null : (selectedRow ?? this.selectedRow),
      selectedCol: clearSelection ? null : (selectedCol ?? this.selectedCol),
      timeRemaining: timeRemaining ?? this.timeRemaining,
      timeLimitSecs: timeLimitSecs ?? this.timeLimitSecs,
      timeTaken: timeTaken ?? this.timeTaken,
      score: score ?? this.score,
    );
  }
}
