import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:games_services/games_services.dart' as gs;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage.dart';
import 'play_games_config.dart';
import '../core/l10n.dart';

/// 랭킹 기간.
enum RankPeriod {
  weekly('이번 주', 'This week'),
  allTime('전체', 'All time');

  const RankPeriod(this.koLabel, this.enLabel);
  final String koLabel;
  final String enLabel;
  String get label => isKorean ? koLabel : enLabel;
}

/// 랭킹 한 줄.
class RankEntry {
  const RankEntry({required this.rank, required this.name, required this.score, this.isMe = false});

  final int rank;
  final String name;
  final int score;
  final bool isMe;
}

/// 랭킹 기능. 실제 구현은 Play 게임즈, 웹·테스트·미설정 상태에서는 꺼진 구현을 쓴다.
abstract class LeaderboardService {
  /// 이 기기·빌드에서 랭킹을 쓸 수 있는지 (설정이 돼 있고 안드로이드인지).
  bool get available;

  /// 로그인 (Play 게임즈는 보통 자동 로그인). 성공하면 true.
  Future<bool> signIn();

  Future<bool> get isSignedIn;

  /// 점수 등록. 실패하면 false (나중에 다시 보낸다).
  Future<bool> submit(int score);

  /// 상위 순위. 실패하면 null.
  Future<List<RankEntry>?> top(RankPeriod period, {int max = 20});

  /// 내 순위. 기록이 없거나 실패하면 null.
  Future<RankEntry?> me(RankPeriod period);

  /// 구글 기본 랭킹 화면 열기.
  Future<void> showNative(RankPeriod period);
}

/// 랭킹이 꺼진 상태 (웹, 테스트, 리더보드 ID 미설정).
class DisabledLeaderboard implements LeaderboardService {
  const DisabledLeaderboard();

  @override
  bool get available => false;
  @override
  Future<bool> signIn() async => false;
  @override
  Future<bool> get isSignedIn async => false;
  @override
  Future<bool> submit(int score) async => false;
  @override
  Future<List<RankEntry>?> top(RankPeriod period, {int max = 20}) async => null;
  @override
  Future<RankEntry?> me(RankPeriod period) async => null;
  @override
  Future<void> showNative(RankPeriod period) async {}
}

/// Play 게임즈 리더보드.
class PlayGamesLeaderboard implements LeaderboardService {
  PlayGamesLeaderboard(this.leaderboardId);

  final String leaderboardId;

  static gs.TimeScope _scope(RankPeriod p) => p == RankPeriod.weekly ? gs.TimeScope.week : gs.TimeScope.allTime;

  @override
  bool get available => true;

  @override
  Future<bool> signIn() async {
    try {
      if (await gs.GamesServices.isSignedIn) return true;
      await gs.GamesServices.signIn();
      return await gs.GamesServices.isSignedIn;
    } catch (e) {
      debugPrint('play games sign-in failed: $e');
      return false;
    }
  }

  @override
  Future<bool> get isSignedIn async {
    try {
      return await gs.GamesServices.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> submit(int score) async {
    try {
      if (!await signIn()) return false;
      await gs.GamesServices.submitScore(score: gs.Score(androidLeaderboardID: leaderboardId, value: score));
      return true;
    } catch (e) {
      debugPrint('submit score failed: $e');
      return false;
    }
  }

  @override
  Future<List<RankEntry>?> top(RankPeriod period, {int max = 20}) async {
    try {
      if (!await signIn()) return null;
      final myId = await gs.GamesServices.getPlayerID();
      final list = await gs.Leaderboards.loadLeaderboardScores(
        androidLeaderboardID: leaderboardId,
        scope: gs.PlayerScope.global,
        timeScope: _scope(period),
        maxResults: max,
        forceRefresh: true,
      );
      return list
          ?.map((e) => RankEntry(
                rank: e.rank,
                name: e.scoreHolder.displayName,
                score: e.rawScore,
                isMe: myId != null && e.scoreHolder.playerID == myId,
              ))
          .toList();
    } catch (e) {
      debugPrint('load leaderboard failed: $e');
      return null;
    }
  }

  @override
  Future<RankEntry?> me(RankPeriod period) async {
    try {
      if (!await signIn()) return null;
      final s = await gs.Leaderboards.getPlayerScoreObject(
        androidLeaderboardID: leaderboardId,
        scope: gs.PlayerScope.global,
        timeScope: _scope(period),
      );
      if (s == null || s.rank <= 0) return null;
      return RankEntry(rank: s.rank, name: s.scoreHolder.displayName, score: s.rawScore, isMe: true);
    } catch (e) {
      debugPrint('load my rank failed: $e');
      return null;
    }
  }

  @override
  Future<void> showNative(RankPeriod period) async {
    try {
      if (!await signIn()) return;
      await gs.GamesServices.showLeaderboards(androidLeaderboardID: leaderboardId, timeScope: _scope(period));
    } catch (e) {
      debugPrint('show leaderboard failed: $e');
    }
  }
}

/// 화면 확인용 예시 랭킹. `--dart-define=DEMO_LEADERBOARD=true` 로 빌드할 때만 쓴다.
class DemoLeaderboard implements LeaderboardService {
  int _mine = 0;

  @override
  bool get available => true;
  @override
  Future<bool> signIn() async => true;
  @override
  Future<bool> get isSignedIn async => true;
  @override
  Future<bool> submit(int score) async {
    if (score > _mine) _mine = score;
    return true;
  }

  List<RankEntry> _all(RankPeriod p) {
    const names = ['파스텔왕', 'SymmetryPro', '대칭요정', 'mint_choco', '돌려돌려', 'Lavender', '퍼즐냥', 'rushhour', '하늘색', '콤보장인'];
    final base = p == RankPeriod.weekly ? 4200 : 9800;
    final list = [
      for (int i = 0; i < names.length; i++) (names[i], base - i * (p == RankPeriod.weekly ? 310 : 640)),
      (tr('나'), _mine > 0 ? _mine : (p == RankPeriod.weekly ? 2900 : 3600)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (int i = 0; i < list.length; i++)
        RankEntry(rank: i + 1, name: list[i].$1, score: list[i].$2, isMe: list[i].$1 == tr('나')),
    ];
  }

  @override
  Future<List<RankEntry>?> top(RankPeriod period, {int max = 20}) async => _all(period).take(max).toList();
  @override
  Future<RankEntry?> me(RankPeriod period) async => _all(period).firstWhere((e) => e.isMe);
  @override
  Future<void> showNative(RankPeriod period) async {}
}

/// 앱에서 쓰는 랭킹 서비스. 테스트에서는 가짜로 바꿔 끼운다.
final leaderboardProvider = Provider<LeaderboardService>((ref) {
  if (const bool.fromEnvironment('DEMO_LEADERBOARD')) return DemoLeaderboard();
  final configured = kRushLeaderboardAndroidId.isNotEmpty;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && configured) {
    return PlayGamesLeaderboard(kRushLeaderboardAndroidId);
  }
  return const DisabledLeaderboard();
});

/// 러시 점수 등록을 맡는다. 인터넷이 없거나 로그인에 실패하면
/// 가장 높은 미전송 점수를 기억해 두었다가 다음에 다시 보낸다.
class ScoreUploader {
  ScoreUploader(this._service, this._prefs);

  static const _pendingKey = 'pendingRushScore';

  final LeaderboardService _service;
  final SharedPreferences _prefs;

  int get pending => _prefs.getInt(_pendingKey) ?? 0;

  /// 점수를 보낸다. 성공하면 true.
  Future<bool> submit(int score) async {
    if (!_service.available || score <= 0) return false;
    final best = score > pending ? score : pending;
    final ok = await _service.submit(best);
    if (ok) {
      await _prefs.remove(_pendingKey);
    } else {
      await _prefs.setInt(_pendingKey, best);
    }
    return ok;
  }

  /// 예전에 못 보낸 점수가 있으면 보낸다 (앱 시작 때 등).
  Future<void> flush() async {
    if (pending > 0) await submit(pending);
  }
}

final scoreUploaderProvider = Provider<ScoreUploader>(
  (ref) => ScoreUploader(ref.watch(leaderboardProvider), ref.watch(prefsProvider)),
);
