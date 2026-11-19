import 'logic/board.dart';
import 'logic/generator.dart';
import 'logic/rules.dart';
import 'logic/symmetry.dart';

enum Phase {
  /// 시작 전 3-2-1 카운트다운.
  countdown,
  playing,

  /// 퍼즐을 풀었거나 실패해서 다음 퍼즐로 넘어가는 중.
  transition,
  paused,
  over,
}

/// 힌트 표시: swap 할 두 칸 또는 회전.
class Hint {
  const Hint.swap(int this.a, int this.b) : rotate = false;
  const Hint.rotate()
      : a = null,
        b = null,
        rotate = true;

  final int? a;
  final int? b;
  final bool rotate;

  bool covers(int cell) => cell == a || cell == b;
}

class GameSession {
  const GameSession({
    required this.mode,
    required this.difficulty,
    required this.puzzle,
    required this.board,
    required this.tileIds,
    required this.phase,
    required this.remainingMs,
    required this.timeCapMs,
    required this.hintsLeft,
    this.puzzleSerial = 0,
    this.rotations = 0,
    this.movesUsed = 0,
    this.selected,
    this.score = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.cleared = 0,
    this.hint,
    this.feverMs = 0,
    this.countdown = 3,
    this.won = false,
    this.stars = 0,
    this.newRecord = false,
    this.lastClearMs = 0,
    this.pausedFrom,
    this.expired = false,
    this.undosLeft = 0,
    this.canUndoMove = false,
    this.stuck = false,
    this.stageNumber,
    this.starGain = 0,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final Puzzle puzzle;
  final Board board;

  /// tileIds[cell] = 그 칸에 놓인 타일의 고유 id (애니메이션용).
  final List<int> tileIds;
  final Phase phase;
  final int remainingMs;
  final int timeCapMs;
  final int hintsLeft;

  /// 퍼즐이 바뀔 때마다 1씩 증가.
  final int puzzleSerial;

  /// 이번 퍼즐에서 회전한 횟수 (회전 애니메이션 트리거용).
  final int rotations;
  final int movesUsed;
  final int? selected;
  final int score;
  final int combo;
  final int maxCombo;
  final int cleared;
  final Hint? hint;

  /// 남은 피버 시간. 0 이면 피버 아님.
  final int feverMs;
  final int countdown;
  final bool won;
  final int stars;
  final bool newRecord;
  final int lastClearMs;
  final Phase? pausedFrom;

  /// 오래 자리를 비워서 끝난 판인지 (러시 백그라운드 타임아웃).
  final bool expired;

  /// 남은 되돌리기 수.
  final int undosLeft;

  /// 이번 퍼즐에서 되돌릴 swap 이 있는지.
  final bool canUndoMove;

  /// 남은 이동으로는 더 풀 수 없는 상태 (되돌리기나 패스만 가능).
  final bool stuck;

  /// 클래식 스테이지 번호 (1~100). 러시는 null.
  final int? stageNumber;

  /// 이번 클리어로 늘어난 별 수 (클래식 스테이지).
  final int starGain;

  bool get canUndo => canAct && canUndoMove && undosLeft > 0;

  SymmetryType get target => puzzle.target;
  int get maxMoves => puzzle.maxMoves;
  int get movesLeft => puzzle.maxMoves - movesUsed;
  int get stage => cleared + 1;
  bool get isFever => feverMs > 0;
  bool get canAct => phase == Phase.playing;
  double get timeFraction => (remainingMs / timeCapMs).clamp(0.0, 1.0);
  bool get isTimeCritical => remainingMs <= 10000;

  /// 회전하기만 하면 완성되는 상태인지.
  bool get rotateToWin =>
      target.rotated != target &&
      !board.isSymmetric(target) &&
      board.isSymmetric(target.rotated);

  GameSession copyWith({
    Puzzle? puzzle,
    Board? board,
    List<int>? tileIds,
    Phase? phase,
    int? remainingMs,
    int? hintsLeft,
    int? puzzleSerial,
    int? rotations,
    int? movesUsed,
    int? selected,
    bool clearSelection = false,
    int? score,
    int? combo,
    int? maxCombo,
    int? cleared,
    Hint? hint,
    bool clearHint = false,
    int? feverMs,
    int? countdown,
    bool? won,
    int? stars,
    bool? newRecord,
    int? lastClearMs,
    Phase? pausedFrom,
    bool? expired,
    int? undosLeft,
    bool? canUndoMove,
    bool? stuck,
    int? starGain,
  }) {
    return GameSession(
      mode: mode,
      difficulty: difficulty,
      puzzle: puzzle ?? this.puzzle,
      board: board ?? this.board,
      tileIds: tileIds ?? this.tileIds,
      phase: phase ?? this.phase,
      remainingMs: remainingMs ?? this.remainingMs,
      timeCapMs: timeCapMs,
      hintsLeft: hintsLeft ?? this.hintsLeft,
      puzzleSerial: puzzleSerial ?? this.puzzleSerial,
      rotations: rotations ?? this.rotations,
      movesUsed: movesUsed ?? this.movesUsed,
      selected: clearSelection ? null : (selected ?? this.selected),
      score: score ?? this.score,
      combo: combo ?? this.combo,
      maxCombo: maxCombo ?? this.maxCombo,
      cleared: cleared ?? this.cleared,
      hint: clearHint ? null : (hint ?? this.hint),
      feverMs: feverMs ?? this.feverMs,
      countdown: countdown ?? this.countdown,
      won: won ?? this.won,
      stars: stars ?? this.stars,
      newRecord: newRecord ?? this.newRecord,
      lastClearMs: lastClearMs ?? this.lastClearMs,
      pausedFrom: pausedFrom ?? this.pausedFrom,
      expired: expired ?? this.expired,
      undosLeft: undosLeft ?? this.undosLeft,
      canUndoMove: canUndoMove ?? this.canUndoMove,
      stuck: stuck ?? this.stuck,
      stageNumber: stageNumber,
      starGain: starGain ?? this.starGain,
    );
  }
}

// ── UI 연출용 이벤트 ─────────────────────────────────────────────
sealed class GameEvent {
  const GameEvent();
}

class CountdownTick extends GameEvent {
  const CountdownTick(this.value);

  /// 3, 2, 1, 0(GO)
  final int value;
}

class SwapEvent extends GameEvent {
  const SwapEvent(this.a, this.b, this.newlyMatched);
  final int a;
  final int b;
  final List<int> newlyMatched;
}

/// 같은 색끼리 바꾸려 한 경우 (이동 수는 쓰지 않음).
class InvalidSwapEvent extends GameEvent {
  const InvalidSwapEvent(this.a, this.b);
  final int a;
  final int b;
}

/// 막혔다: 되돌리기나 패스를 기다린다.
class StuckEvent extends GameEvent {
  const StuckEvent();
}

/// 한 수 물렀다.
class UndoEvent extends GameEvent {
  const UndoEvent();
}

class RotateEvent extends GameEvent {
  const RotateEvent();
}

class ClearEvent extends GameEvent {
  const ClearEvent({
    required this.gain,
    required this.timeBonusMs,
    required this.combo,
    required this.perfect,
    required this.fast,
  });
  final int gain;
  final int timeBonusMs;
  final int combo;
  final bool perfect;
  final bool fast;
}

enum FailReason { stuck, outOfMoves, skipped }

class FailEvent extends GameEvent {
  const FailEvent(this.reason, this.penaltyMs);
  final FailReason reason;
  final int penaltyMs;
}

class FeverEvent extends GameEvent {
  const FeverEvent(this.started);
  final bool started;
}

class NewPuzzleEvent extends GameEvent {
  const NewPuzzleEvent();
}

class HintEvent extends GameEvent {
  const HintEvent(this.hint);
  final Hint hint;
}

class TimeUpEvent extends GameEvent {
  const TimeUpEvent();
}

/// 러시 도중 오래 자리를 비워서 판이 끝났다.
class SessionExpiredEvent extends GameEvent {
  const SessionExpiredEvent();
}

class GameOverEvent extends GameEvent {
  const GameOverEvent();
}
