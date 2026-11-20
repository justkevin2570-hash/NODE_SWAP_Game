import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_swap_game/audio/audio_engine.dart';
import 'package:node_swap_game/core/storage.dart';
import 'package:node_swap_game/game/game_controller.dart';
import 'package:node_swap_game/game/logic/rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('테마마다 필요한 음악 파일(OGG)이 모두 있다', () {
    expect(File('assets/audio/music/menu.ogg').existsSync(), isTrue);
    for (final t in MusicTheme.values) {
      final files = t.files;
      expect(files.keys, contains(Music.play));
      expect(files.keys, contains(Music.tense));
      expect(files.containsKey(Music.fever), !t.isStage, reason: t.name); // 스테이지에는 피버가 없다
      for (final f in files.values) {
        expect(File('assets/audio/music/$f.ogg').existsSync(), isTrue, reason: f);
      }
    }
    // 예전 WAV 음악은 남아 있지 않다 (앱 크기)
    final wavs = Directory('assets/audio/music').listSync().where((e) => e.path.endsWith('.wav'));
    expect(wavs, isEmpty);
  });

  testWidgets('러시는 판마다 다른 테마, 스테이지는 판 크기별 테마', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final audio = AudioEngine.silent();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      audioProvider.overrideWithValue(audio),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(gameProvider.notifier);
    final seen = <MusicTheme>[];
    for (int i = 0; i < 3; i++) {
      ctrl.start(GameMode.rush);
      seen.add(audio.currentTheme!);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(seen.toSet(), MusicTheme.rushThemes.toSet()); // 3판 연속이면 세 테마가 한 번씩
    for (final (b, t) in [
      (BoardSize.five, MusicTheme.stageFive),
      (BoardSize.seven, MusicTheme.stageSeven),
      (BoardSize.nine, MusicTheme.stageNine),
    ]) {
      ctrl.start(GameMode.classic, boardSize: b, stage: 1);
      expect(audio.currentTheme, t);
      await tester.pump(const Duration(milliseconds: 100));
    }
    ctrl.quit();
  });
}
