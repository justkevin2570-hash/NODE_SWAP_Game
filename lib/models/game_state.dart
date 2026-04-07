import 'board_model.dart';

enum Difficulty { easy, normal, hard }

enum GamePhase { playing, won, lost }

class GameConfig {
  static const Map<Difficulty, int> maxMoves = {
    Difficulty.easy: 6,
    Difficulty.normal: 5,
    Difficulty.hard: 4,
  };
  static const Map<Difficulty, int> shuffleSteps = {
    Difficulty.easy: 4,   // swap 4회 + 회전 1회
    Difficulty.normal: 5,  // swap 5회 + 회전 1회
    Difficulty.hard: 6,   // swap 6회 + 회전 1회
  };
  static const Map<Difficulty, int> hintCount = {
    Difficulty.easy: 3,
    Difficulty.normal: 2,
    Difficulty.hard: 1,
  };
  static const Map<Difficulty, int> timeLimitSecs = {
    Difficulty.easy: 120,
    Difficulty.normal: 90,
    Difficulty.hard: 60,
  };
}

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
  final int timeTaken;
  final int score;
  final int comboCount;
  final int maxCombo;

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
    this.timeTaken = 0,
    this.score = 0,
    this.comboCount = 0,
    this.maxCombo = 0,
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
    );
  }

  bool get isSelected => selectedRow != null && selectedCol != null;
  bool get canMove => moveCount < maxMoves && phase == GamePhase.playing;
  bool get canHint => hintsRemaining > 0 && phase == GamePhase.playing;
  bool get isTimeCritical => timeRemaining <= 10;

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
    int? timeTaken,
    int? score,
    int? comboCount,
    int? maxCombo,
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
      timeTaken: timeTaken ?? this.timeTaken,
      score: score ?? this.score,
      comboCount: comboCount ?? this.comboCount,
      maxCombo: maxCombo ?? this.maxCombo,
    );
  }
}
