import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio/audio_engine.dart';
import 'core/theme.dart';
import 'ui/screens/title_screen.dart';

class SymmetryRushApp extends ConsumerWidget {
  const SymmetryRushApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Symmetry Rush',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // 웹은 첫 터치 이후에만 소리를 낼 수 있어서, 어떤 터치든 오디오를 깨운다.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(audioProvider).unlock(),
        child: child,
      ),
      home: const TitleScreen(),
    );
  }
}
