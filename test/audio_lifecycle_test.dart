import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/audio/audio_engine.dart';

void main() {
  testWidgets('앱이 백그라운드로 가면 소리를 멈추고, 돌아오면 다시 낸다', (tester) async {
    final engine = AudioEngine()..attachLifecycle();
    addTearDown(engine.dispose);
    expect(engine.debugInBackground, isFalse);

    // 홈 버튼 → hidden → paused
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(engine.debugInBackground, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(engine.debugInBackground, isTrue);

    // 백그라운드에서 곡이 바뀌어도(예: 결과 화면) 기억만 하고 재생하지 않는다
    await engine.setMusic(Music.menu);
    expect(engine.currentMusic, Music.menu);
    expect(engine.debugInBackground, isTrue);

    // 다시 앱으로
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(engine.debugInBackground, isFalse);
  });

  testWidgets('테스트용 무음 엔진은 생명주기를 구독하지 않는다', (tester) async {
    final engine = AudioEngine.silent()..attachLifecycle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(engine.debugInBackground, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    engine.dispose();
  });
}
