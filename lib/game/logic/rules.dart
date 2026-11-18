import 'dart:math';

import 'generator.dart';
import 'symmetry.dart';

enum GameMode { rush, classic }

enum Difficulty {
  easy('쉬움'),
  normal('보통'),
  hard('어려움');

  const Difficulty(this.label);
  final String label;
}

/// 게임 밸런스 수치는 모두 여기에 모아 둔다.
abstract final class Rules {
  // ── 러시 모드 ───────────────────────────────────────────
  static const int rushStartMs = 60000;
  static const int rushTimeCapMs = 60000;
  static const int rushHints = 3;

  /// 한 판(러시는 한 번의 도전 전체)에 쓸 수 있는 되돌리기 수. 클래식은 [classicUndos].
  static const int rushUndos = 3;

  /// 이동 수를 다 쓰고 실패했을 때 깎이는 시간.
  static const int rushFailPenaltyMs = 5000;

  /// 러시 도중 앱 밖에 이만큼 넘게 있다가 돌아오면 그 판을 끝낸다 (점수는 기록에 반영).
  /// 클래식은 시간 제한 없이 일시정지 상태로 기다린다.
  static const Duration rushBackgroundTimeout = Duration(minutes: 5);

  /// 이 시간 안에 퍼즐을 풀면 콤보가 이어진다.
  static const int comboWindowMs = 8000;

  /// 콤보가 이 배수에 도달할 때마다 피버 발동.
  static const int feverEvery = 5;
  static const int feverDurationMs = 8000;

  static PuzzleSpec rushSpec(int stage) {
    const hv = [SymmetryType.horizontal, SymmetryType.vertical];
    const basic = [SymmetryType.horizontal, SymmetryType.vertical, SymmetryType.point];
    const all = SymmetryType.values;
    if (stage <= 2) {
      return const PuzzleSpec(scrambleSwaps: 2, slack: 1, types: hv);
    }
    if (stage <= 5) {
      return const PuzzleSpec(scrambleSwaps: 3, slack: 1, types: basic);
    }
    // 6 스테이지부터 대각선(y=x, y=−x) 대칭이 섞여 나온다.
    if (stage <= 9) {
      return const PuzzleSpec(scrambleSwaps: 4, slack: 1, types: all);
    }
    if (stage <= 14) {
      return const PuzzleSpec(scrambleSwaps: 5, slack: 1, types: all);
    }
    if (stage <= 20) {
      return const PuzzleSpec(scrambleSwaps: 5, slack: 0, types: all);
    }
    return const PuzzleSpec(scrambleSwaps: 6, slack: 0, types: all);
  }

  /// 퍼즐을 풀었을 때 돌려받는 시간.
  static int rushTimeBonusMs(int movesLeft) => 4000 + movesLeft * 1000;

  /// 러시 모드 클리어 점수.
  static int rushClearScore({
    required int stage,
    required int movesUsed,
    required int par,
    required int maxMoves,
    required int clearMs,
    required int combo,
    required bool fever,
  }) {
    final base = 100 + 25 * (stage - 1);
    final efficiency = (maxMoves - movesUsed) * 30 + (movesUsed <= par ? 100 : 0);
    final speed = clearMs <= 3000
        ? 150
        : clearMs <= 6000
            ? 75
            : 0;
    return ((base + efficiency + speed) * comboMultiplier(combo, fever: fever))
        .round();
  }

  static double comboMultiplier(int combo, {bool fever = false}) {
    final m = min(3.0, 1.0 + 0.25 * max(0, combo - 1));
    return fever ? m * 2 : m;
  }

  // ── 클래식 모드 ─────────────────────────────────────────
  static PuzzleSpec classicSpec(Difficulty d) => switch (d) {
        Difficulty.easy => const PuzzleSpec(
            scrambleSwaps: 3, slack: 2, types: SymmetryType.values),
        Difficulty.normal => const PuzzleSpec(
            scrambleSwaps: 4, slack: 1, types: SymmetryType.values),
        Difficulty.hard => const PuzzleSpec(
            scrambleSwaps: 5, slack: 0, types: SymmetryType.values),
      };

  static int classicTimeMs(Difficulty d) => switch (d) {
        Difficulty.easy => 90000,
        Difficulty.normal => 60000,
        Difficulty.hard => 45000,
      };

  static int classicHints(Difficulty d) => switch (d) {
        Difficulty.easy => 3,
        Difficulty.normal => 2,
        Difficulty.hard => 1,
      };

  static int classicUndos(Difficulty d) => classicHints(d);

  static int classicStars({required int movesUsed, required int par}) {
    if (movesUsed <= par) return 3;
    if (movesUsed <= par + 1) return 2;
    return 1;
  }

  static int classicScore({
    required Difficulty difficulty,
    required int movesUsed,
    required int maxMoves,
    required int remainingMs,
    required int stars,
  }) {
    final base = switch (difficulty) {
      Difficulty.easy => 500,
      Difficulty.normal => 800,
      Difficulty.hard => 1200,
    };
    return base +
        (maxMoves - movesUsed) * 100 +
        (remainingMs ~/ 1000) * 10 +
        stars * 100;
  }
}
