import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_engine.dart';
import '../core/storage.dart';
import 'game_state.dart';
import 'logic/board.dart';
import 'logic/generator.dart';
import 'logic/rules.dart';
import 'logic/solver.dart';

/// 게임 한 판의 진행을 담당한다. 상태는 [GameSession], 연출은 [events] 로 알린다.
class GameController extends Notifier<GameSession?> {
  static const _tickMs = 50;
  static const _countdownStepMs = 600;
  static const _clearTransitionMs = 750;
  static const _failTransitionMs = 650;

  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  final PuzzleGenerator _generator = PuzzleGenerator();

  /// 미리 만들어 둔 러시 퍼즐 (스테이지 → 퍼즐).
  /// 높은 스테이지는 퍼즐 하나 만드는 데 최대 0.2초쯤 걸려서, 전환 순간에 만들면 화면이 멈칫한다.
  /// 그래서 지금 퍼즐을 푸는 동안 다음에 필요할 퍼즐(클리어 시 다음 스테이지, 실패 시 같은 스테이지)을
  /// 백그라운드 isolate 에서 만들어 둔다.
  final Map<int, Puzzle> _ready = {};
  final Set<int> _preparing = {};
  int _gameId = 0;
  Timer? _timer;
  Stopwatch _clock = clock.stopwatch();
  int _lastTick = 0;
  int _phaseAcc = 0; // 카운트다운·전환 단계에서 흐른 시간
  int _puzzleElapsed = 0; // 현재 퍼즐을 푸는 데 걸린 시간
  Solution? _solution; // 현재 보드의 최적 풀이 (힌트·막힘 판정용)
  bool _pendingNext = false; // 전환이 끝나면 새 퍼즐로 갈지

  AudioEngine get _audio => ref.read(audioProvider);

  @override
  GameSession? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _events.close();
    });
    return null;
  }

  // ── 시작 ────────────────────────────────────────────────
  /// 새 판을 시작한다. 클래식에서 [puzzle] 을 주면 그 퍼즐을 처음부터 다시 한다.
  void start(GameMode mode, {Difficulty difficulty = Difficulty.normal, Puzzle? puzzle}) {
    puzzle = mode == GameMode.rush
        ? _generator.generate(Rules.rushSpec(1))
        : puzzle ?? _generator.generate(Rules.classicSpec(difficulty));
    final time = mode == GameMode.rush ? Rules.rushStartMs : Rules.classicTimeMs(difficulty);
    state = GameSession(
      mode: mode,
      difficulty: difficulty,
      puzzle: puzzle,
      board: puzzle.board,
      tileIds: List.generate(Board.cellCount, (i) => i),
      phase: Phase.countdown,
      remainingMs: time,
      timeCapMs: mode == GameMode.rush ? Rules.rushTimeCapMs : time,
      hintsLeft: mode == GameMode.rush ? Rules.rushHints : Rules.classicHints(difficulty),
      undosLeft: mode == GameMode.rush ? Rules.rushUndos : Rules.classicUndos(difficulty),
      countdown: 3,
    );
    _solution = Solver(puzzle.target).solve(puzzle.board, maxDepth: puzzle.maxMoves);
    _phaseAcc = 0;
    _puzzleElapsed = 0;
    _pendingNext = false;
    _gameId++;
    _history.clear();
    _hiddenAt = null;
    _ready.clear();
    _preparing.clear();
    if (mode == GameMode.rush) _prefetchAround(1);
    _clock = clock.stopwatch()..start();
    _lastTick = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _tick());
    _emit(const CountdownTick(3));
    _audio.play(Sfx.countdown);
    _audio.setMusic(Music.play);
  }

  void quit() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  // ── 시간 흐름 ───────────────────────────────────────────
  void _tick() {
    final now = _clock.elapsedMilliseconds;
    // 실제 흐른 시간 (프레임이 크게 밀려도 한 번에 0.25초 이상은 깎지 않는다).
    final dt = min(250, now - _lastTick);
    _lastTick = now;
    final s = state;
    if (s == null) return;

    switch (s.phase) {
      case Phase.countdown:
        _phaseAcc += dt;
        final step = _phaseAcc ~/ _countdownStepMs;
        final value = 3 - step;
        if (value != s.countdown) {
          if (value <= 0) {
            state = s.copyWith(countdown: 0, phase: Phase.playing);
            _emit(const CountdownTick(0));
            _audio.play(Sfx.go);
            _audio.haptic(HapticKind.medium);
          } else {
            state = s.copyWith(countdown: value);
            _emit(CountdownTick(value));
            _audio.play(Sfx.countdown);
          }
        }
      case Phase.playing:
        _puzzleElapsed += dt;
        if (s.isFever) {
          final left = s.feverMs - dt;
          if (left <= 0) {
            state = s.copyWith(feverMs: 0);
            _emit(const FeverEvent(false));
          } else {
            state = s.copyWith(feverMs: left);
          }
        } else {
          final before = s.remainingMs;
          final after = max(0, before - dt);
          state = s.copyWith(remainingMs: after);
          _secondTicks(before, after);
          if (after <= 0) _timeUp();
        }
        _updateMusic();
      case Phase.transition:
        _phaseAcc -= dt;
        if (_phaseAcc <= 0) _finishTransition();
      case Phase.paused:
      case Phase.over:
        break;
    }
  }

  void _secondTicks(int before, int after) {
    if (before ~/ 1000 == after ~/ 1000 || after > 10000 || after <= 0) return;
    if (after <= 5000) {
      _audio.play(Sfx.tickUrgent);
      _audio.haptic(HapticKind.light);
    } else {
      _audio.play(Sfx.tick);
    }
  }

  void _updateMusic() {
    final s = state;
    if (s == null) return;
    final tenseAt = s.mode == GameMode.rush ? 15000 : 10000;
    final Music want;
    if (s.phase == Phase.over) {
      want = Music.none;
    } else if (s.isFever) {
      want = Music.fever;
    } else if (s.remainingMs <= tenseAt) {
      want = Music.tense;
    } else {
      want = Music.play;
    }
    if (_audio.currentMusic != want) {
      _audio.setMusic(want, fade: const Duration(milliseconds: 400));
    }
  }

  // ── 입력 ────────────────────────────────────────────────
  void tapCell(int cell) {
    final s = state;
    if (s == null || !s.canAct || s.stuck) return;
    final sel = s.selected;
    if (sel == null) {
      state = s.copyWith(selected: cell);
      _audio.play(Sfx.select);
      _audio.haptic(HapticKind.selection);
    } else if (sel == cell) {
      state = s.copyWith(clearSelection: true);
      _audio.play(Sfx.tap, volume: 0.6);
    } else if (Board.isAdjacent(sel, cell)) {
      swap(sel, cell);
    } else {
      state = s.copyWith(selected: cell);
      _audio.play(Sfx.select);
      _audio.haptic(HapticKind.selection);
    }
  }

  /// 드래그로 바로 swap 할 때도 사용.
  void swap(int a, int b) {
    final s = state;
    if (s == null || !s.canAct || s.stuck || !Board.isAdjacent(a, b)) return;
    if (s.movesLeft <= 0) {
      _audio.play(Sfx.error);
      return;
    }
    if (s.board[a] == s.board[b]) {
      // 같은 색끼리는 바꿔도 의미가 없으니 이동 수를 쓰지 않는다.
      state = s.copyWith(clearSelection: true);
      _emit(InvalidSwapEvent(a, b));
      _audio.play(Sfx.error);
      return;
    }
    _history.add((board: s.board, tileIds: s.tileIds, movesUsed: s.movesUsed));
    final before = s.board.matchedCells(s.target);
    final board = s.board.swap(a, b);
    final ids = List.of(s.tileIds);
    final t = ids[a];
    ids[a] = ids[b];
    ids[b] = t;
    final after = board.matchedCells(s.target);
    final newly = after.difference(before).toList();

    state = s.copyWith(
      board: board,
      tileIds: ids,
      movesUsed: s.movesUsed + 1,
      canUndoMove: true,
      clearSelection: true,
      clearHint: true,
    );
    _emit(SwapEvent(a, b, newly));
    _audio.play(Sfx.swap);
    _audio.haptic(HapticKind.light);
    if (newly.isNotEmpty) {
      final progress = board.symmetryProgress(s.target);
      _audio.play(Sfx.match((progress * 6).round()));
    }
    _afterMove();
  }

  void rotate() {
    final s = state;
    if (s == null || !s.canAct || s.stuck) return;
    final board = s.board.rotateCW();
    final ids = List<int>.filled(Board.cellCount, 0);
    for (int i = 0; i < Board.cellCount; i++) {
      ids[Board.rotatedIndex(i)] = s.tileIds[i];
    }
    state = s.copyWith(
      board: board,
      tileIds: ids,
      rotations: s.rotations + 1,
      clearSelection: true,
      clearHint: true,
    );
    _emit(const RotateEvent());
    _audio.play(Sfx.rotate);
    _audio.haptic(HapticKind.light);
    _afterMove();
  }

  void useHint() {
    final s = state;
    if (s == null || !s.canAct || s.stuck || s.hintsLeft <= 0 || s.hint != null) return;
    final sol = _solution ?? Solver(s.target).solve(s.board, maxDepth: s.movesLeft);
    if (sol == null) return;
    final Hint hint;
    if (sol.swaps.isEmpty) {
      hint = const Hint.rotate();
    } else {
      final (a, b) = sol.swaps.first;
      hint = Hint.swap(a, b);
    }
    state = s.copyWith(hint: hint, hintsLeft: s.hintsLeft - 1, clearSelection: true);
    _emit(HintEvent(hint));
    _audio.play(Sfx.hint);
  }

  /// 러시 모드: 이번 퍼즐을 건너뛴다 (시간 감점, 콤보 초기화).
  void skip() {
    final s = state;
    if (s == null || !s.canAct || s.mode != GameMode.rush) return;
    _fail(FailReason.skipped);
  }

  void pause() {
    final s = state;
    // 퍼즐 전환 중에도 멈춘다 (안 그러면 앱 밖에 있는 동안 시간이 흐를 수 있다).
    if (s == null || !const [Phase.playing, Phase.countdown, Phase.transition].contains(s.phase)) return;
    state = s.copyWith(phase: Phase.paused, pausedFrom: s.phase);
    _audio.duck(true);
  }

  void resume() {
    final s = state;
    if (s == null || s.phase != Phase.paused) return;
    state = s.copyWith(phase: s.pausedFrom ?? Phase.playing);
    _lastTick = _clock.elapsedMilliseconds;
    _audio.duck(false);
  }

  /// 처음부터: 클래식은 같은 퍼즐을 처음부터, 러시는 새 도전(60초)으로.
  void restart() {
    final s = state;
    if (s == null) return;
    _audio.duck(false);
    start(s.mode, difficulty: s.difficulty, puzzle: s.mode == GameMode.classic ? s.puzzle : null);
  }

  /// 클래식: 새 퍼즐로 바꾼다.
  void newPuzzle() {
    final s = state;
    if (s == null) return;
    _audio.duck(false);
    start(s.mode, difficulty: s.difficulty);
  }

  // ── 판정 ────────────────────────────────────────────────
  void _afterMove() {
    final s = state!;
    if (s.board.isSymmetric(s.target)) {
      _clear();
      return;
    }
    _solution = Solver(s.target).solve(s.board, maxDepth: s.movesLeft);
    if (_solution == null) {
      if (s.undosLeft > 0 && _history.isNotEmpty) {
        // 바로 실패시키지 않고, 되돌리기(또는 러시의 패스)를 기다린다.
        state = s.copyWith(stuck: true, clearSelection: true, clearHint: true);
        _emit(const StuckEvent());
        _audio.play(Sfx.error);
        _audio.haptic(HapticKind.medium);
        return;
      }
      _fail(s.movesLeft <= 0 ? FailReason.outOfMoves : FailReason.stuck);
    }
  }

  // ── 되돌리기 ─────────────────────────────────────────────
  final List<({Board board, List<int> tileIds, int movesUsed})> _history = [];

  /// 직전 swap 을 무른다 (이동 수도 돌려받음). 되돌리기 횟수를 하나 쓴다.
  void undo() {
    final s = state;
    if (s == null || !s.canUndo || _history.isEmpty) return;
    final prev = _history.removeLast();
    state = s.copyWith(
      board: prev.board,
      tileIds: prev.tileIds,
      movesUsed: prev.movesUsed,
      undosLeft: s.undosLeft - 1,
      canUndoMove: _history.isNotEmpty,
      stuck: false,
      clearSelection: true,
      clearHint: true,
    );
    _solution = Solver(s.target).solve(prev.board, maxDepth: s.maxMoves - prev.movesUsed);
    _emit(const UndoEvent());
    _audio.play(Sfx.whoosh);
    _audio.haptic(HapticKind.light);
  }

  void _clear() {
    final s = state!;
    final clearMs = _puzzleElapsed;
    final perfect = s.movesUsed <= s.puzzle.par;
    final fast = clearMs <= 3000;

    if (s.mode == GameMode.classic) {
      final stars = Rules.classicStars(movesUsed: s.movesUsed, par: s.puzzle.par);
      final score = Rules.classicScore(
        difficulty: s.difficulty,
        movesUsed: s.movesUsed,
        maxMoves: s.maxMoves,
        remainingMs: s.remainingMs,
        stars: stars,
      );
      final record = ref.read(recordsProvider.notifier).submitClassic(s.difficulty, score: score, stars: stars);
      state = s.copyWith(
        phase: Phase.over,
        won: true,
        stars: stars,
        score: score,
        newRecord: record,
        cleared: 1,
        lastClearMs: clearMs,
        clearSelection: true,
      );
      _emit(ClearEvent(gain: score, timeBonusMs: 0, combo: 1, perfect: perfect, fast: fast));
      _emit(const GameOverEvent());
      _audio.play(Sfx.clear);
      _audio.haptic(HapticKind.medium);
      _audio.setMusic(Music.none, fade: const Duration(milliseconds: 300));
      _timer?.cancel();
      return;
    }

    // 러시 모드
    final combo = clearMs <= Rules.comboWindowMs ? s.combo + 1 : 1;
    final gain = Rules.rushClearScore(
      stage: s.stage,
      movesUsed: s.movesUsed,
      par: s.puzzle.par,
      maxMoves: s.maxMoves,
      clearMs: clearMs,
      combo: combo,
      fever: s.isFever,
    );
    final bonus = Rules.rushTimeBonusMs(s.movesLeft);
    final startFever = !s.isFever && combo >= Rules.feverEvery && combo % Rules.feverEvery == 0;
    state = s.copyWith(
      phase: Phase.transition,
      score: s.score + gain,
      combo: combo,
      maxCombo: max(s.maxCombo, combo),
      cleared: s.cleared + 1,
      remainingMs: min(s.timeCapMs, s.remainingMs + bonus),
      feverMs: startFever ? Rules.feverDurationMs : s.feverMs,
      lastClearMs: clearMs,
      clearSelection: true,
      clearHint: true,
    );
    _phaseAcc = _clearTransitionMs;
    _pendingNext = true;
    _emit(ClearEvent(gain: gain, timeBonusMs: bonus, combo: combo, perfect: perfect, fast: fast));
    _audio.play(Sfx.clear);
    _audio.play(Sfx.bonus, volume: 0.7);
    _audio.haptic(HapticKind.medium);
    if (combo >= 2) _audio.play(combo >= 4 ? Sfx.comboBig : Sfx.combo);
    if (startFever) {
      _emit(const FeverEvent(true));
      _audio.play(Sfx.fever);
      _audio.haptic(HapticKind.heavy);
      _updateMusic();
    }
  }

  void _fail(FailReason reason) {
    final s = state!;
    _audio.haptic(HapticKind.heavy);
    if (s.mode == GameMode.classic) {
      state = s.copyWith(phase: Phase.over, won: false, clearSelection: true, clearHint: true);
      _emit(FailEvent(reason, 0));
      _emit(const GameOverEvent());
      _audio.play(Sfx.fail);
      _audio.setMusic(Music.none, fade: const Duration(milliseconds: 300));
      _timer?.cancel();
      return;
    }
    final penalty = reason == FailReason.skipped ? 3000 : Rules.rushFailPenaltyMs;
    state = s.copyWith(
      phase: Phase.transition,
      combo: 0,
      remainingMs: max(0, s.remainingMs - penalty),
      clearSelection: true,
      clearHint: true,
    );
    _phaseAcc = _failTransitionMs;
    _pendingNext = true;
    _emit(FailEvent(reason, penalty));
    _audio.play(reason == FailReason.skipped ? Sfx.whoosh : Sfx.fail);
  }

  void _finishTransition() {
    final s = state!;
    if (s.remainingMs <= 0) {
      _timeUp();
      return;
    }
    if (_pendingNext) {
      _pendingNext = false;
      final puzzle = _ready.remove(s.stage) ?? _generator.generate(Rules.rushSpec(s.stage));
      _prefetchAround(s.stage);
      _solution = Solver(puzzle.target).solve(puzzle.board, maxDepth: puzzle.maxMoves);
      _puzzleElapsed = 0;
      state = s.copyWith(
        phase: Phase.playing,
        puzzle: puzzle,
        board: puzzle.board,
        tileIds: List.generate(Board.cellCount, (i) => i + (s.puzzleSerial + 1) * 100),
        puzzleSerial: s.puzzleSerial + 1,
        rotations: 0,
        movesUsed: 0,
        canUndoMove: false,
        stuck: false,
        clearSelection: true,
        clearHint: true,
      );
      _history.clear();
      _emit(const NewPuzzleEvent());
      _audio.play(Sfx.whoosh, volume: 0.6);
    } else {
      state = s.copyWith(phase: Phase.playing);
    }
  }

  /// 지금 스테이지(실패·패스 대비)와 다음 스테이지(클리어 대비) 퍼즐을 미리 만든다.
  void _prefetchAround(int stage) {
    _ready.removeWhere((st, _) => st < stage); // 지나간 스테이지 것은 버린다
    for (final st in [stage, stage + 1]) {
      if (_ready.containsKey(st) || _preparing.contains(st)) continue;
      _preparing.add(st);
      final game = _gameId;
      final spec = Rules.rushSpec(st);
      _generateInBackground(spec).then((p) {
        if (game != _gameId) return; // 그 사이 새 게임이 시작됐으면 버린다
        _preparing.remove(st);
        _ready[st] = p;
      }, onError: (_) => _preparing.remove(st));
    }
  }

  Future<Puzzle> _generateInBackground(PuzzleSpec spec) {
    // 웹은 isolate 를 못 쓰니, 전환 순간을 피해 조금 뒤에 만든다.
    if (kIsWeb) {
      return Future.delayed(const Duration(milliseconds: 400), () => _generator.generate(spec));
    }
    return generatePuzzleInIsolate(spec);
  }

  // ── 앱이 화면에서 사라졌다 돌아올 때 ──────────────────────
  DateTime? _hiddenAt;

  /// 앱이 백그라운드로 갔다: 시각을 기억하고 일시정지.
  void appHidden() {
    final s = state;
    if (s == null || s.phase == Phase.over) return;
    _hiddenAt ??= clock.now();
    pause();
  }

  /// 앱으로 돌아왔다: 러시에서 너무 오래 비웠으면 그 판을 끝낸다.
  void appShown() {
    final at = _hiddenAt;
    _hiddenAt = null;
    final s = state;
    if (at == null || s == null || s.phase == Phase.over) return;
    if (s.mode == GameMode.rush && clock.now().difference(at) >= Rules.rushBackgroundTimeout) {
      _endRun(expired: true);
    }
  }

  void _timeUp() => _endRun(expired: false);

  /// 판을 끝내고 기록을 저장한다. 러시는 시간이 다 됐거나(expired=false) 오래 비웠을 때(expired=true).
  void _endRun({required bool expired}) {
    final s = state!;
    _timer?.cancel();
    final record = s.mode == GameMode.rush
        ? ref.read(recordsProvider.notifier).submitRush(score: s.score, cleared: s.cleared)
        : false;
    state = s.copyWith(
      phase: Phase.over,
      remainingMs: expired ? s.remainingMs : 0,
      won: false,
      newRecord: record,
      feverMs: 0,
      expired: expired,
      clearSelection: true,
      clearHint: true,
    );
    _audio.duck(false);
    _emit(expired ? const SessionExpiredEvent() : const TimeUpEvent());
    _emit(const GameOverEvent());
    _audio.play(Sfx.gameover);
    if (!expired) _audio.haptic(HapticKind.heavy);
    _audio.setMusic(Music.none, fade: const Duration(milliseconds: 500));
  }

  void _emit(GameEvent e) {
    if (!_events.isClosed) _events.add(e);
  }
}

final gameProvider = NotifierProvider<GameController, GameSession?>(GameController.new);
