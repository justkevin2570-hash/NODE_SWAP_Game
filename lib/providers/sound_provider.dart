import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SoundEvent { tap, swap, combo, comboMax, win, lose, tick, tickFast }

class SoundNotifier extends StateNotifier<bool> {
  // state = isMuted
  AudioPlayer? _winPlayer;
  AudioPlayer? _losePlayer;
  final Map<SoundEvent, AudioPool> _pools = {};
  bool _initialized = false;

  SoundNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    try {
      _winPlayer = AudioPlayer();
      _losePlayer = AudioPlayer();

      final shortSounds = {
        SoundEvent.tap: 'sounds/tap.wav',
        SoundEvent.swap: 'sounds/swap.wav',
        SoundEvent.combo: 'sounds/combo.wav',
        SoundEvent.comboMax: 'sounds/combo_max.wav',
        SoundEvent.tick: 'sounds/tick.wav',
        SoundEvent.tickFast: 'sounds/tick_fast.wav',
      };

      for (final entry in shortSounds.entries) {
        _pools[entry.key] =
            await AudioPool.createFromAsset(path: entry.value, maxPlayers: 4);
      }
      _initialized = true;
    } catch (_) {
      // 사운드 초기화 실패 시 무음으로 동작
    }
  }

  Future<void> play(SoundEvent event) async {
    if (state || !_initialized) return;
    try {
      if (event == SoundEvent.win) {
        await _winPlayer?.stop();
        await _winPlayer?.play(AssetSource('sounds/win.wav'));
      } else if (event == SoundEvent.lose) {
        await _losePlayer?.stop();
        await _losePlayer?.play(AssetSource('sounds/lose.wav'));
      } else {
        await _pools[event]?.start(volume: 1.0);
      }
    } catch (_) {}
  }

  void toggleMute() => state = !state;

  @override
  void dispose() {
    _winPlayer?.dispose();
    _losePlayer?.dispose();
    for (final pool in _pools.values) {
      pool.dispose();
    }
    super.dispose();
  }
}

final soundProvider =
    StateNotifierProvider<SoundNotifier, bool>((_) => SoundNotifier());
