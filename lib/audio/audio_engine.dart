import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
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

  /// 동시에 겹쳐 울릴 수 있는 수. 이 개수만큼만 플레이어를 만들어 돌려 쓴다.
  int get voices => switch (this) {
        tap || select || swap || button => 3,
        tick || tickUrgent || error || bonus || combo => 2,
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

  /// 효과음마다 미리 만들어 둔 플레이어들. 개수가 고정이라 오래 플레이해도 늘어나지 않는다.
  /// (audioplayers 의 AudioPool 은 lowLatency 모드에서 재생이 끝난 플레이어를 돌려받지 못해
  /// 소리를 낼 때마다 새 플레이어를 만들고 해제하지 않는다 → 점점 느려지고 음악이 끊긴다.)
  final Map<Sfx, _Voices> _sfx = {};
  final Map<Music, AudioPlayer> _music = {};
  final Map<Music, double> _musicLevel = {};
  Music _current = Music.none;
  Timer? _fadeTimer;
  bool _ready = false;
  bool _unlocked = !kIsWeb; // 웹은 첫 터치 전까지 소리를 낼 수 없다
  bool _ducked = false;

  /// 앱이 백그라운드(홈 화면, 다른 앱, 화면 꺼짐)에 있는 동안은 아무 소리도 내지 않는다.
  bool _background = false;
  AppLifecycleListener? _lifecycle;

  @visibleForTesting
  bool get debugInBackground => _background;

  /// 앱이 화면에서 사라지면 음악을 멈추고, 돌아오면 이어서 재생한다.
  void attachLifecycle() {
    if (!enabled || _lifecycle != null) return;
    _lifecycle = AppLifecycleListener(
      onHide: _enterBackground,
      onPause: _enterBackground,
      onShow: _leaveBackground,
      onResume: _leaveBackground,
    );
  }

  void _enterBackground() {
    if (_background) return;
    _background = true;
    _fadeTimer?.cancel();
    // 페이드 도중이었다면 목표 상태로 정리해 두고 모두 멈춘다.
    for (final m in _music.keys) {
      _musicLevel[m] = m == _current ? 1.0 : 0.0;
      _music[m]!.pause().catchError((_) {});
    }
  }

  void _leaveBackground() {
    if (!_background) return;
    _background = false;
    if (!enabled || !_ready || !_unlocked) return;
    final p = _music[_current];
    if (p == null) return;
    p.setVolume(_vol(_current)).catchError((_) {});
    p.resume().catchError((_) {});
  }

  double _vol(Music m) => (_musicLevel[m] ?? 0) * _musicVolume * (_ducked ? 0.3 : 1.0);

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
      final players = <AudioPlayer>[];
      for (int i = 0; i < s.voices; i++) {
        final p = AudioPlayer(playerId: 'sfx_${s.file}_$i');
        await p.setPlayerMode(kIsWeb ? PlayerMode.mediaPlayer : PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('audio/sfx/${s.file}.wav'));
        players.add(p);
      }
      _sfx[s] = _Voices(players);
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
      e.value.setVolume(_vol(e.key)).catchError((_) {});
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
    if (!enabled || !_ready || !_unlocked || _background || _sfxVolume <= 0) return;
    _sfx[s]?.play(min(1.0, s.gain * volume * _sfxVolume));
  }

  /// 테스트·디버그용: 지금까지 만든 효과음 플레이어 수 (항상 고정이어야 한다).
  int get sfxPlayerCount => _sfx.values.fold(0, (n, v) => n + v.players.length);

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
    if (_background) {
      // 백그라운드에서는 곡만 바꿔 두고, 돌아왔을 때 그 곡을 재생한다.
      for (final m in _music.keys) {
        _musicLevel[m] = m == next ? 1.0 : 0.0;
        if (m != next) _music[m]!.pause().catchError((_) {});
      }
      if (next.isGameLayer && prev.isGameLayer) {
        try {
          final pos = await _music[prev]?.getCurrentPosition();
          if (pos != null) await _music[next]?.seek(pos);
        } catch (_) {}
      } else {
        await _music[next]?.seek(Duration.zero).catchError((_) {});
      }
      return;
    }

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
        _music[m]!.setVolume(_vol(m)).catchError((_) {});
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
    _ducked = on;
    for (final e in _music.entries) {
      e.value.setVolume(_vol(e.key)).catchError((_) {});
    }
  }

  void dispose() {
    _fadeTimer?.cancel();
    _lifecycle?.dispose();
    for (final v in _sfx.values) {
      for (final p in v.players) {
        p.dispose();
      }
    }
    for (final p in _music.values) {
      p.dispose();
    }
  }
}

enum HapticKind { selection, light, medium, heavy }

/// 한 효과음의 플레이어 묶음. 돌아가며 재사용한다.
class _Voices {
  _Voices(this.players);

  final List<AudioPlayer> players;
  int _next = 0;

  /// 플레이어별로 명령을 순서대로 이어 붙여서, 겹쳐 눌러도 stop/resume 이 꼬이지 않게 한다.
  late final List<Future<void>> _chains = List.filled(players.length, Future.value());

  void play(double volume) {
    final i = _next;
    _next = (_next + 1) % players.length;
    final p = players[i];
    _chains[i] = _chains[i].then((_) async {
      try {
        await p.stop();
        await p.setVolume(volume);
        await p.resume();
      } catch (_) {}
    });
  }
}

final audioProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine();
  ref.listen(settingsProvider, (_, s) => engine.applySettings(s), fireImmediately: true);
  engine.attachLifecycle();
  engine.init();
  ref.onDispose(engine.dispose);
  return engine;
});
