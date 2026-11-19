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

  /// 이 크기를 할 수 있는지: 5×5 는 처음부터, 7×7·9×9 는 앞 크기를 [Rules.sizeUnlockAt]탄 깨면 열린다.
  bool isSizeUnlocked(BoardSize d) {
    final prev = d.previous;
    return prev == null || clearedCount(prev) >= Rules.sizeUnlockAt;
  }
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

