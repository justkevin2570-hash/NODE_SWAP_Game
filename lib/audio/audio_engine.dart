import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage.dart';

/// 효과음 목록. 파일은 `assets/audio/sfx/{file}.wav`
enum Sfx {
  tap('tap', 0.6),
  select('select', 0.7),
  swap('swap', 0.8),
  rotate('rotate', 0.8),
  clear('clear', 0.9),
  combo('combo', 0.8),
  comboBig('combo_big', 0.9),
  fever('fever', 1.0),
  tick('tick', 0.5),
  tickUrgent('tick_urgent', 0.6),
  fail('fail', 0.8),
  error('error', 0.35),
  countdown('countdown', 0.8),
  go('go', 0.9),
  gameover('gameover', 0.9),
  fanfare('fanfare', 0.9),
  button('button', 0.6),
  hint('hint', 0.8),
  bonus('bonus', 0.7),
  whoosh('whoosh', 0.6),
  match0('match_0', 0.55),
  match1('match_1', 0.55),
  match2('match_2', 0.55),
  match3('match_3', 0.55),
  match4('match_4', 0.55),
  match5('match_5', 0.55),
  match6('match_6', 0.55),
  star0('star_0', 0.8),
  star1('star_1', 0.8),
  star2('star_2', 0.8);

  const Sfx(this.file, this.gain);
  final String file;
  final double gain;

  static Sfx match(int step) => [match0, match1, match2, match3, match4, match5, match6][step.clamp(0, 6)];
  static Sfx star(int i) => [star0, star1, star2][i.clamp(0, 2)];

  /// 자주 겹쳐 울리는 소리는 플레이어를 여러 개 둔다.
  int get voices => switch (this) {
        tap || select || swap || tick || button || match0 || match1 || match2 || match3 || match4 || match5 || match6 => 3,
        _ => 1,
      };
}

enum Music {
  none(null),
  menu('menu'),
  play('play'),
  tense('tense'),
  fever('fever');

  const Music(this.file);
  final String? file;

  /// play/tense/fever 는 같은 템포·길이라 재생 위치를 맞춰 전환한다.
  bool get isGameLayer => this == play || this == tense || this == fever;
}

/// 음악·효과음·진동을 한 곳에서 관리한다.
/// 플랫폼 오디오가 없는 환경(테스트 등)에서는 조용히 아무것도 하지 않는다.
class AudioEngine {
  AudioEngine({this.enabled = true});

  /// 테스트용: 아무 소리도 내지 않는 엔진.
  factory AudioEngine.silent() => AudioEngine(enabled: false);

  final bool enabled;
  double _musicVolume = 0.5;
  double _sfxVolume = 0.8;
  bool _haptics = true;

  final Map<Sfx, AudioPool> _pools = {};
  final Map<Music, AudioPlayer> _music = {};
  final Map<Music, double> _musicLevel = {};
  Music _current = Music.none;
  Timer? _fadeTimer;
  bool _ready = false;
  bool _unlocked = !kIsWeb; // 웹은 첫 터치 전까지 소리를 낼 수 없다

  Future<void> init() async {
    if (!enabled || _ready) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (_) {}
    await Future.wait([
      for (final s in Sfx.values) _loadSfx(s),
      for (final m in Music.values)
        if (m.file != null) _loadMusic(m),
    ]);
    _ready = true;
    if (_current != Music.none) {
      final want = _current;
      _current = Music.none;
      setMusic(want);
    }
  }

  Future<void> _loadSfx(Sfx s) async {
    try {
      _pools[s] = await AudioPool.createFromAsset(
        path: 'audio/sfx/${s.file}.wav',
        maxPlayers: s.voices,
        playerMode: kIsWeb ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('sfx load failed: ${s.file} $e');
    }
  }

  Future<void> _loadMusic(Music m) async {
    try {
      final p = AudioPlayer(playerId: 'music_${m.name}');
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setSource(AssetSource('audio/music/${m.file}.wav'));
      await p.setVolume(0);
      _music[m] = p;
      _musicLevel[m] = 0;
    } catch (e) {
      debugPrint('music load failed: ${m.file} $e');
    }
  }

  void applySettings(Settings s) {
    _musicVolume = s.musicVolume;
    _sfxVolume = s.sfxVolume;
    _haptics = s.haptics;
    for (final e in _music.entries) {
      e.value.setVolume((_musicLevel[e.key] ?? 0) * _musicVolume);
    }
  }

  /// 웹에서 첫 사용자 입력 때 호출해 오디오를 깨운다.
  void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    if (_current != Music.none) {
      final want = _current;
      _current = Music.none;
      setMusic(want);
    }
  }

  // ── 효과음 ───────────────────────────────────────────────
  void play(Sfx s, {double volume = 1.0}) {
    if (!enabled || !_ready || !_unlocked || _sfxVolume <= 0) return;
    final pool = _pools[s];
    if (pool == null) return;
    pool.start(volume: min(1.0, s.gain * volume * _sfxVolume)).catchError((_) => () async {});
  }

  // ── 진동 ─────────────────────────────────────────────────
  void haptic(HapticKind kind) {
    if (!enabled || !_haptics || kIsWeb) return;
    switch (kind) {
      case HapticKind.selection:
        HapticFeedback.selectionClick();
      case HapticKind.light:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  // ── 배경음악 ─────────────────────────────────────────────
  Music get currentMusic => _current;

  Future<void> setMusic(Music next, {Duration fade = const Duration(milliseconds: 600)}) async {
    if (next == _current) return;
    final prev = _current;
    _current = next;
    if (!enabled || !_ready || !_unlocked) return;

    final nextPlayer = _music[next];
    if (nextPlayer != null) {
      try {
        Duration? syncPos;
        if (prev.isGameLayer && next.isGameLayer) {
          syncPos = await _music[prev]?.getCurrentPosition();
        }
        await nextPlayer.seek(syncPos ?? Duration.zero);
        await nextPlayer.resume();
      } catch (_) {}
    }
    _fadeTo(next, fade);
  }

  void _fadeTo(Music target, Duration fade) {
    _fadeTimer?.cancel();
    const step = Duration(milliseconds: 40);
    final steps = max(1, fade.inMilliseconds ~/ step.inMilliseconds);
    final start = Map<Music, double>.from(_musicLevel);
    var i = 0;
    _fadeTimer = Timer.periodic(step, (t) {
      i++;
      final k = i / steps;
      for (final m in _music.keys) {
        final goal = m == target ? 1.0 : 0.0;
        final v = (start[m] ?? 0) + (goal - (start[m] ?? 0)) * k;
        _musicLevel[m] = v;
        _music[m]!.setVolume(v * _musicVolume).catchError((_) {});
      }
      if (i >= steps) {
        t.cancel();
        for (final m in _music.keys) {
          if (m != target) _music[m]!.pause().catchError((_) {});
        }
      }
    });
  }

  /// 일시정지 화면 등에서 음악을 잠깐 줄인다.
  void duck(bool on) {
    for (final e in _music.entries) {
      final level = (_musicLevel[e.key] ?? 0) * (on ? 0.3 : 1.0);
      e.value.setVolume(level * _musicVolume).catchError((_) {});
    }
  }

  void dispose() {
    _fadeTimer?.cancel();
    for (final p in _pools.values) {
      p.dispose();
    }
    for (final p in _music.values) {
      p.dispose();
    }
  }
}

enum HapticKind { selection, light, medium, heavy }

final audioProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine();
  ref.listen(settingsProvider, (_, s) => engine.applySettings(s), fireImmediately: true);
  engine.init();
  ref.onDispose(engine.dispose);
  return engine;
});
