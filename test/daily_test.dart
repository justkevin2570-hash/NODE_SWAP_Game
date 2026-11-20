import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/logic/daily.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('오늘의 퍼즐', () {
    test('같은 날짜면 같은 퍼즐, 판 크기는 5x5 → 7x7 → 9x9 로 돈다', () {
      final day = DateTime(2026, 11, 20, 9);
      final a = dailyPuzzle(day);
      final b = dailyPuzzle(DateTime(2026, 11, 20, 23, 59));
      expect(a.board, b.board);
      expect(a.target, b.target);
      expect(dailyKey(day), '2026-11-20');
      expect(dailyYesterdayKey(DateTime(2027, 1, 1)), '2026-12-31');
      final sizes = [for (int i = 0; i < 3; i++) dailySize(DateTime(2026, 11, 20 + i))];
      expect(sizes.toSet(), BoardSize.values.toSet());
      expect(a.board.size, dailySize(day).size);
    });

    test('60일치 퍼즐 모두 풀리고 최소 이동이 범위 안이다', () {
      for (int i = 0; i < 60; i++) {
        final day = DateTime(2026, 11, 1).add(Duration(days: i));
        final p = dailyPuzzle(day);
        final (lo, hi) = Rules.dailyPar(dailySize(day));
        final s = Solver(p.target).solve(p.board, maxDepth: p.maxMoves)!;
        expect(s.moveCount, p.par, reason: dailyKey(day));
        expect(p.par, inInclusiveRange(lo, hi), reason: dailyKey(day));
        expect(p.maxMoves, p.par + Rules.dailySlack);
      }
    });

    test('연속 기록: 이어 풀면 +1, 같은 날 다시 풀면 그대로, 하루 거르면 1부터', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final n = c.read(dailyProgressProvider.notifier);
      expect(n.record('2026-11-20', '2026-11-19', 2), 1);
      expect(n.record('2026-11-20', '2026-11-19', 3), 1); // 같은 날
      expect(c.read(dailyProgressProvider).lastStars, 3);
      expect(n.record('2026-11-21', '2026-11-20', 1), 2);
      expect(n.record('2026-11-22', '2026-11-21', 1), 3);
      final p = c.read(dailyProgressProvider);
      expect(p.streakOn('2026-11-23', '2026-11-22'), 3); // 오늘 아직 안 풀어도 어제 풀었으면 유지
      expect(p.streakOn('2026-11-24', '2026-11-23'), 0); // 하루 걸렀다
      expect(n.record('2026-11-24', '2026-11-23', 3), 1);
      expect(c.read(dailyProgressProvider).bestStreak, 3);
      expect(prefs.getInt('dailyBest'), 3);
    });
  });
}
