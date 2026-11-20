import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/logic/rules.dart';

/// main() 에서 실제 인스턴스로 override 한다.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

// ── 설정 ──────────────────────────────────────────────────────
class Settings {
  const Settings({
    this.musicVolume = 0.5,
    this.sfxVolume = 0.8,
    this.haptics = true,
    this.tutorialSeen = false,
    this.pairPreview = true,
  });

  final double musicVolume;
  final double sfxVolume;
  final bool haptics;
  final bool tutorialSeen;

  /// 타일을 고르면 대칭 짝 칸을 표시할지.
  final bool pairPreview;

  Settings copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? haptics,
    bool? tutorialSeen,
    bool? pairPreview,
  }) =>
      Settings(
        musicVolume: musicVolume ?? this.musicVolume,
        sfxVolume: sfxVolume ?? this.sfxVolume,
        haptics: haptics ?? this.haptics,
        tutorialSeen: tutorialSeen ?? this.tutorialSeen,
        pairPreview: pairPreview ?? this.pairPreview,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Settings build() {
    final p = ref.watch(prefsProvider);
    return Settings(
      musicVolume: p.getDouble('musicVolume') ?? 0.5,
      sfxVolume: p.getDouble('sfxVolume') ?? 0.8,
      haptics: p.getBool('haptics') ?? true,
      tutorialSeen: p.getBool('tutorialSeen') ?? false,
      pairPreview: p.getBool('pairPreview') ?? true,
    );
  }

  void setMusicVolume(double v) {
    state = state.copyWith(musicVolume: v);
    _p.setDouble('musicVolume', v);
  }

  void setSfxVolume(double v) {
    state = state.copyWith(sfxVolume: v);
    _p.setDouble('sfxVolume', v);
  }

  void setHaptics(bool v) {
    state = state.copyWith(haptics: v);
    _p.setBool('haptics', v);
  }

  void setPairPreview(bool v) {
    state = state.copyWith(pairPreview: v);
    _p.setBool('pairPreview', v);
  }

  void markTutorialSeen() {
    state = state.copyWith(tutorialSeen: true);
    _p.setBool('tutorialSeen', true);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ── 기록 ──────────────────────────────────────────────────────
class Records {
  const Records({
    this.rushBestScore = 0,
    this.rushBestStage = 0,
  });

  final int rushBestScore;

  /// 러시 모드에서 가장 많이 푼 퍼즐 수.
  final int rushBestStage;
}

class RecordsNotifier extends Notifier<Records> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Records build() {
    final p = ref.watch(prefsProvider);
    return Records(
      rushBestScore: p.getInt('rushBestScore') ?? 0,
      rushBestStage: p.getInt('rushBestStage') ?? 0,
    );
  }

  /// 신기록이면 true.
  bool submitRush({required int score, required int cleared}) {
    final isRecord = score > state.rushBestScore;
    final bestStage = cleared > state.rushBestStage ? cleared : state.rushBestStage;
    state = Records(
      rushBestScore: isRecord ? score : state.rushBestScore,
      rushBestStage: bestStage,
    );
    _p.setInt('rushBestScore', state.rushBestScore);
    _p.setInt('rushBestStage', bestStage);
    return isRecord;
  }

  void reset() {
    for (final k in _p.getKeys().toList()) {
      if (k.startsWith('rush') || k.startsWith('classic')) _p.remove(k);
    }
    state = const Records();
  }
}

final recordsProvider =
    NotifierProvider<RecordsNotifier, Records>(RecordsNotifier.new);

// ── 클래식 스테이지 진행 ─────────────────────────────────────────
/// 판 크기별 100탄의 별 개수(0~3). 0 이면 아직 못 깬 탄.
class StageProgress {
  const StageProgress(this.stars);

  final Map<BoardSize, List<int>> stars;

  int starsOf(BoardSize d, int stage) => stars[d]![stage - 1];

  /// 깬 탄 수 (= 다음에 열릴 탄 번호 - 1). 탄은 1탄부터 순서대로 열린다.
  int clearedCount(BoardSize d) {
    final list = stars[d]!;
    var n = 0;
    while (n < list.length && list[n] > 0) {
      n++;
    }
    return n;
  }

  bool isUnlocked(BoardSize d, int stage) => stage <= clearedCount(d) + 1;

  /// 지금 할 차례인 탄 (다 깼으면 마지막 탄).
  int nextStage(BoardSize d) => (clearedCount(d) + 1).clamp(1, Rules.stageCount);

  int totalStars(BoardSize d) => stars[d]!.fold(0, (a, b) => a + b);
}

class StageProgressNotifier extends Notifier<StageProgress> {
  SharedPreferences get _p => ref.read(prefsProvider);

  /// 'stageStars_5x5' 처럼 크기별로 저장한다. (예전 쉬움/보통/어려움 기록은 'stageStars_easy' 등이라 쓰지 않는다.)
  static String _key(BoardSize d) => 'stageStars_${d.size}x${d.size}';
  static const _legacyKeys = ['stageStars_easy', 'stageStars_normal', 'stageStars_hard'];

  @override
  StageProgress build() {
    final p = ref.watch(prefsProvider);
    for (final k in _legacyKeys) {
      if (p.containsKey(k)) p.remove(k); // 판 크기 방식으로 바뀌기 전 기록 정리
    }
    return StageProgress({
      for (final d in BoardSize.values) d: _decode(p.getString(_key(d))),
    });
  }

  static List<int> _decode(String? s) => List.generate(
        Rules.stageCount,
        (i) => s != null && i < s.length ? (int.tryParse(s[i]) ?? 0).clamp(0, 3) : 0,
      );

  /// [stage]탄을 별 [stars]개로 깼다. 기존보다 많을 때만 바뀐다. 늘어난 별 수를 돌려준다.
  int record(BoardSize d, int stage, int stars) {
    final list = List<int>.of(state.stars[d]!);
    final prev = list[stage - 1];
    if (stars <= prev) return 0;
    list[stage - 1] = stars;
    state = StageProgress({...state.stars, d: list});
    _p.setString(_key(d), list.join());
    return stars - prev;
  }

  void reset() {
    for (final d in BoardSize.values) {
      _p.remove(_key(d));
    }
    _legacyKeys.forEach(_p.remove);
    state = build();
  }
}

final stageProgressProvider = NotifierProvider<StageProgressNotifier, StageProgress>(StageProgressNotifier.new);

// ── 오늘의 퍼즐 ─────────────────────────────────────────────
/// 오늘의 퍼즐 기록: 마지막으로 푼 날, 그날 별, 연속 일수, 최고 연속 일수.
class DailyProgress {
  const DailyProgress({this.lastDay, this.lastStars = 0, this.streak = 0, this.bestStreak = 0});

  final String? lastDay;
  final int lastStars;
  final int streak;
  final int bestStreak;

  bool clearedOn(String day) => lastDay == day;

  /// 오늘 기준 이어지고 있는 연속 일수 (어제나 오늘 풀었으면 유지, 아니면 0).
  int streakOn(String today, String yesterday) =>
      lastDay == today || lastDay == yesterday ? streak : 0;
}

class DailyProgressNotifier extends Notifier<DailyProgress> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  DailyProgress build() {
    final p = ref.watch(prefsProvider);
    return DailyProgress(
      lastDay: p.getString('dailyLast'),
      lastStars: p.getInt('dailyStars') ?? 0,
      streak: p.getInt('dailyStreak') ?? 0,
      bestStreak: p.getInt('dailyBest') ?? 0,
    );
  }

  /// [day] 의 퍼즐을 별 [stars]개로 풀었다. 그 뒤의 연속 일수를 돌려준다.
  int record(String day, String yesterday, int stars) {
    final s = state;
    final DailyProgress next;
    if (s.lastDay == day) {
      next = DailyProgress(lastDay: day, lastStars: max(stars, s.lastStars), streak: s.streak, bestStreak: s.bestStreak);
    } else {
      final streak = s.lastDay == yesterday ? s.streak + 1 : 1;
      next = DailyProgress(lastDay: day, lastStars: stars, streak: streak, bestStreak: max(streak, s.bestStreak));
    }
    state = next;
    _p.setString('dailyLast', day);
    _p.setInt('dailyStars', next.lastStars);
    _p.setInt('dailyStreak', next.streak);
    _p.setInt('dailyBest', next.bestStreak);
    return next.streak;
  }

  void reset() {
    for (final k in ['dailyLast', 'dailyStars', 'dailyStreak', 'dailyBest']) {
      _p.remove(k);
    }
    state = build();
  }
}

final dailyProgressProvider = NotifierProvider<DailyProgressNotifier, DailyProgress>(DailyProgressNotifier.new);
