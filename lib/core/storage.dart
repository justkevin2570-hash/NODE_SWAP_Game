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
  });

  final double musicVolume;
  final double sfxVolume;
  final bool haptics;
  final bool tutorialSeen;

  Settings copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? haptics,
    bool? tutorialSeen,
  }) =>
      Settings(
        musicVolume: musicVolume ?? this.musicVolume,
        sfxVolume: sfxVolume ?? this.sfxVolume,
        haptics: haptics ?? this.haptics,
        tutorialSeen: tutorialSeen ?? this.tutorialSeen,
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
    this.classicBest = const {},
    this.classicStars = const {},
  });

  final int rushBestScore;

  /// 러시 모드에서 가장 많이 푼 퍼즐 수.
  final int rushBestStage;
  final Map<Difficulty, int> classicBest;
  final Map<Difficulty, int> classicStars;
}

class RecordsNotifier extends Notifier<Records> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Records build() {
    final p = ref.watch(prefsProvider);
    return Records(
      rushBestScore: p.getInt('rushBestScore') ?? 0,
      rushBestStage: p.getInt('rushBestStage') ?? 0,
      classicBest: {
        for (final d in Difficulty.values) d: p.getInt('classicBest_${d.name}') ?? 0,
      },
      classicStars: {
        for (final d in Difficulty.values) d: p.getInt('classicStars_${d.name}') ?? 0,
      },
    );
  }

  /// 신기록이면 true.
  bool submitRush({required int score, required int cleared}) {
    final isRecord = score > state.rushBestScore;
    final bestStage = cleared > state.rushBestStage ? cleared : state.rushBestStage;
    state = Records(
      rushBestScore: isRecord ? score : state.rushBestScore,
      rushBestStage: bestStage,
      classicBest: state.classicBest,
      classicStars: state.classicStars,
    );
    _p.setInt('rushBestScore', state.rushBestScore);
    _p.setInt('rushBestStage', bestStage);
    return isRecord;
  }

  bool submitClassic(Difficulty d, {required int score, required int stars}) {
    final prev = state.classicBest[d] ?? 0;
    final prevStars = state.classicStars[d] ?? 0;
    final isRecord = score > prev;
    state = Records(
      rushBestScore: state.rushBestScore,
      rushBestStage: state.rushBestStage,
      classicBest: {...state.classicBest, d: isRecord ? score : prev},
      classicStars: {...state.classicStars, d: stars > prevStars ? stars : prevStars},
    );
    _p.setInt('classicBest_${d.name}', state.classicBest[d]!);
    _p.setInt('classicStars_${d.name}', state.classicStars[d]!);
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
