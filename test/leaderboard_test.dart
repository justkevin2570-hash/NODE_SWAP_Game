import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/app.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/game_state.dart';
import 'package:node_swap_game/game/logic/solver.dart';
import 'package:node_swap_game/online/leaderboard.dart';
import 'package:node_swap_game/ui/screens/ranking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테스트용 랭킹 서비스.
class FakeLeaderboard implements LeaderboardService {
  bool online = true;
  bool signedIn = true;
  final submitted = <int>[];
  int myWeeklyRank = 3;

  @override
  bool get available => true;
  @override
  Future<bool> signIn() async => signedIn;
  @override
  Future<bool> get isSignedIn async => signedIn;
  @override
  Future<bool> submit(int score) async {
    if (!online || !signedIn) return false;
    submitted.add(score);
    return true;
  }

  @override
  Future<List<RankEntry>?> top(RankPeriod period, {int max = 20}) async => online
      ? [
          const RankEntry(rank: 1, name: '파스텔왕', score: 9000),
          const RankEntry(rank: 2, name: '대칭요정', score: 7000),
          RankEntry(rank: 3, name: '나', score: submitted.isEmpty ? 5000 : submitted.last, isMe: true),
        ]
      : null;
  @override
  Future<RankEntry?> me(RankPeriod period) async =>
      online ? RankEntry(rank: myWeeklyRank, name: '나', score: submitted.isEmpty ? 0 : submitted.last, isMe: true) : null;
  @override
  Future<void> showNative(RankPeriod period) async {}
}

Future<(ProviderContainer, FakeLeaderboard)> _pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'tutorialSeen': true, ...prefs});
  final p = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final fake = FakeLeaderboard();
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(p),
    audioProvider.overrideWithValue(AudioEngine.silent()),
    leaderboardProvider.overrideWithValue(fake),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SymmetryRushApp()));
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (container, fake);
}

Future<void> _settle(WidgetTester tester, [int steps = 12]) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _cleanup(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  group('ScoreUploader', () {
    test('실패하면 가장 높은 점수를 기억했다가, 다음에 다시 보낸다', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = FakeLeaderboard()..online = false;
      final up = ScoreUploader(fake, prefs);

      expect(await up.submit(500), isFalse);
      expect(await up.submit(300), isFalse);
      expect(up.pending, 500); // 더 높은 점수를 기억

      fake.online = true;
      await up.flush();
      expect(fake.submitted, [500]);
      expect(up.pending, 0);
    });

    test('0점이나 랭킹을 못 쓰는 상태에서는 보내지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(await ScoreUploader(FakeLeaderboard(), prefs).submit(0), isFalse);
      expect(await ScoreUploader(const DisabledLeaderboard(), prefs).submit(100), isFalse);
      expect(prefs.getInt('pendingRushScore'), isNull);
    });
  });

  testWidgets('러시 결과: 점수가 자동으로 올라가고 "이번 주 n위"와 랭킹 보기 버튼이 나온다', (tester) async {
    final (container, fake) = await _pump(tester);
    await tester.tap(find.text('러시 시작'));
    await tester.pump();
    await _settle(tester, 6);
    await tester.pump(const Duration(milliseconds: 2000));
    // 한 판 풀어서 점수를 만든 뒤 시간 종료까지
    final ctrl = container.read(gameProvider.notifier);
    final s = container.read(gameProvider)!;
    final sol = Solver(s.target).solve(s.board)!;
    for (final (a, b) in sol.swaps) {
      ctrl.swap(a, b);
    }
    if (sol.needsRotation) ctrl.rotate();
    await tester.pump(const Duration(milliseconds: 900));
    final score = container.read(gameProvider)!.score;
    for (int i = 0; i < 70; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(container.read(gameProvider)!.phase, Phase.over);
    await _settle(tester, 30);

    expect(fake.submitted, [score]);
    expect(find.text('이번 주 3위'), findsOneWidget);
    expect(find.text('랭킹 보기'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('타이틀의 트로피 버튼 → 랭킹 화면: 순위 목록과 내 순위', (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.emoji_events_rounded));
    await tester.pump();
    await _settle(tester);
    expect(find.byType(RankingScreen), findsOneWidget);
    expect(find.text('파스텔왕'), findsOneWidget);
    expect(find.text('9,000'), findsOneWidget);
    expect(find.text('내 순위'), findsOneWidget);
    // 탭 바꾸기
    await tester.tap(find.text('전체'));
    await _settle(tester);
    expect(find.text('대칭요정'), findsOneWidget);
    await _cleanup(tester);
  });

  testWidgets('로그인이 안 되면 로그인 안내, 인터넷이 없으면 다시 시도 안내', (tester) async {
    final (_, fake) = await _pump(tester);
    fake.signedIn = false;
    await tester.tap(find.byIcon(Icons.emoji_events_rounded));
    await tester.pump();
    await _settle(tester);
    expect(find.text('로그인'), findsOneWidget);

    fake
      ..signedIn = true
      ..online = false;
    await tester.tap(find.text('로그인'));
    await _settle(tester);
    expect(find.text('다시 시도'), findsOneWidget);
    await _cleanup(tester);
  });
}
