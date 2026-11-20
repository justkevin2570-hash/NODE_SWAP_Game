import 'dart:math';

import 'generator.dart';
import 'rules.dart';
import 'symmetry.dart';

/// 오늘의 퍼즐: 날짜마다 정해진 퍼즐 한 판 (모든 사람이 같은 날 같은 퍼즐을 푼다).
/// 판 크기는 날짜에 따라 5x5 → 7x7 → 9x9 로 돌아간다.

/// 기준일(2026-01-01)부터 며칠째인지. 시간대와 상관없이 그 날짜(연·월·일)만 본다.
int dailyDayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026, 1, 1)).inDays;

/// 저장용 날짜 키 (예: 2026-11-20).
String dailyKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// 그 전날의 키.
String dailyYesterdayKey(DateTime day) => dailyKey(DateTime(day.year, day.month, day.day - 1));

BoardSize dailySize(DateTime day) => BoardSize.values[dailyDayNumber(day) % BoardSize.values.length];

/// [day] 의 퍼즐. 같은 날짜면 언제 만들어도 같은 퍼즐이 나온다.
Puzzle dailyPuzzle(DateTime day) {
  final size = dailySize(day);
  final rng = Random(day.year * 10000 + day.month * 100 + day.day);
  final type = SymmetryType.values[rng.nextInt(SymmetryType.values.length)];
  final (lo, hi) = Rules.dailyPar(size);
  final gen = PuzzleGenerator(rng);
  late Puzzle p;
  for (int i = 0; i < 60; i++) {
    p = gen.generate(
      PuzzleSpec(scrambleSwaps: hi, slack: Rules.dailySlack, types: [type], size: size.size),
      forcedType: type,
    );
    if (p.par >= lo && p.par <= hi) return p;
  }
  return p;
}
