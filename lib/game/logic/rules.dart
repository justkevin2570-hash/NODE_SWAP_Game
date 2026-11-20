import 'dart:math';

import 'generator.dart';
import 'symmetry.dart';

enum GameMode { rush, classic }

/// 클래식 판 크기. 판이 클수록 어렵고, 크기마다 100탄이 쉬운 것부터 어려운 것으로 이어진다.
/// 러시는 늘 5×5.
enum BoardSize {
  five(5),
  seven(7),
  nine(9);

  const BoardSize(this.size);

  /// 한 변의 칸 수.
  final int size;

  String get label => '${size}x$size'; // Jua 글꼴에 × 기호가 없어서 x 를 쓴다

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

  // ── 클래식 모드 (판 크기별 100탄) ──────────────────────
  static const int stageCount = 100;


  /// 탄 번호(1~100)에 따른 최소 이동 범위와 나오는 대칭. 탄이 올라갈수록 조금씩 어려워진다.
  /// 이 곡선으로 tool/generate_stages.dart 가 퍼즐을 미리 만들어 stages_data.dart 에 저장한다.
  static ({int minPar, int maxPar, List<SymmetryType> types}) stageCurve(BoardSize b, int stage) {
    const hv = [SymmetryType.horizontal, SymmetryType.vertical];
    const hvp = [SymmetryType.horizontal, SymmetryType.vertical, SymmetryType.point];
    const all = SymmetryType.values;
    // (1~20탄, 21~50탄, 51~80탄, 81~100탄) 의 최소 이동 범위
    final ranges = switch (b) {
      BoardSize.five => const [(1, 2), (2, 3), (3, 4), (4, 5)],
      BoardSize.seven => const [(2, 3), (3, 4), (4, 6), (6, 7)],
      BoardSize.nine => const [(3, 4), (4, 5), (5, 7), (7, 8)],
    };
    final band = stage <= 20
        ? 0
        : stage <= 50
            ? 1
            : stage <= 80
                ? 2
                : 3;
    final (lo, hi) = ranges[band];
    return (minPar: lo, maxPar: hi, types: band == 0 ? hv : band == 1 ? hvp : all);
  }

  /// 최소 이동에 더해 주는 여유 이동: 1~30탄 +2, 31~70탄 +1, 71~100탄 +0.
  static int stageSlack(int stage) => stage <= 30
      ? 2
      : stage <= 70
          ? 1
          : 0;

  // ── 오늘의 퍼즐 ───────────────────────────────────────
  /// 판 크기별 최소 이동 범위 (그 크기의 중간~뒤쪽 탄 정도).
  static (int, int) dailyPar(BoardSize b) => switch (b) {
        BoardSize.five => (4, 5),
        BoardSize.seven => (5, 6),
        BoardSize.nine => (6, 7),
      };

  static const int dailySlack = 1;

  static int classicTimeMs(BoardSize b) => switch (b) {
        BoardSize.five => 60000,
        BoardSize.seven => 90000,
        BoardSize.nine => 120000,
      };

  /// 힌트·되돌리기 수: 1~70탄 3번, 71~100탄 2번.
  static int classicHints(int stage) => stage <= 70 ? 3 : 2;

  static int classicUndos(int stage) => classicHints(stage);

  static int classicStars({required int movesUsed, required int par}) {
    if (movesUsed <= par) return 3;
    if (movesUsed <= par + 1) return 2;
    return 1;
  }

  static int classicScore({
    required BoardSize boardSize,
    required int movesUsed,
    required int maxMoves,
    required int remainingMs,
    required int stars,
  }) {
    final base = switch (boardSize) {
      BoardSize.five => 500,
      BoardSize.seven => 800,
      BoardSize.nine => 1200,
    };
    return base +
        (maxMoves - movesUsed) * 100 +
        (remainingMs ~/ 1000) * 10 +
        stars * 100;
  }
}
