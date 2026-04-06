import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  GameTimerNotifier() : super(0);

  void start(int seconds) {
    _timer?.cancel();
    state = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      } else {
        _timer?.cancel();
      }
    });
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    state = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final gameTimerProvider =
    StateNotifierProvider<GameTimerNotifier, int>((_) => GameTimerNotifier());
