import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/logic/board.dart';
import '../../game/logic/generator.dart';
import '../../game/logic/rules.dart';
import '../../game/logic/symmetry.dart';
import '../widgets/board_view.dart';
import '../widgets/bubbly.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/pastel_background.dart';
import 'game_screen.dart';
import 'sheets.dart';
import 'tutorial_screen.dart';

class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});

  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(audioProvider).setMusic(Music.menu));
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(softRoute(page));
    if (mounted) ref.read(audioProvider).setMusic(Music.menu, fade: const Duration(milliseconds: 900));
  }

  void _startRush() {
    final seen = ref.read(settingsProvider).tutorialSeen;
    _go(seen ? const GameScreen(mode: GameMode.rush) : const TutorialScreen(then: GameMode.rush));
  }

  Future<void> _openClassic() async {
    final d = await showClassicSheet(context);
    if (d != null && mounted) _go(GameScreen(mode: GameMode.classic, difficulty: d));
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    return Scaffold(
      body: PastelBackground(
        child: SafeArea(
          child: PhoneColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: LayoutBuilder(builder: (context, c) {
                final demo = (c.maxHeight * 0.3).clamp(150.0, 250.0);
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        RoundIconButton(
                          icon: Icons.settings_rounded,
                          onPressed: () => showSettingsSheet(context),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const _Logo(),
                    const SizedBox(height: 10),
                    Text('밀고 · 돌리고 · 대칭을 완성하세요!',
                            style: TextStyles.body.copyWith(color: Palette.inkSoft, fontSize: 17))
                        .animate()
                        .fadeIn(delay: 700.ms),
                    const Spacer(),
                    _DemoBoard(size: demo),
                    const Spacer(),
                    BubblyButton(
                      label: '러시 시작',
                      subtitle: records.rushBestScore > 0
                          ? '최고 ${RollingNumber.formatInt(records.rushBestScore)}점 · ${records.rushBestStage}스테이지'
                          : '60초 동안 최대한 많이!',
                      icon: Icons.bolt_rounded,
                      color: Palette.pink,
                      deep: Palette.pinkDeep,
                      width: double.infinity,
                      height: 76,
                      fontSize: 28,
                      glow: true,
                      onPressed: _startRush,
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5, curve: Curves.easeOutBack),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: BubblyButton(
                            label: '클래식',
                            icon: Icons.extension_rounded,
                            color: Palette.sky,
                            deep: Palette.skyDeep,
                            height: 60,
                            onPressed: _openClassic,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BubblyButton(
                            label: '배우기',
                            icon: Icons.school_rounded,
                            color: Palette.mint,
                            deep: Palette.mintDeep,
                            height: 60,
                            onPressed: () => _go(const TutorialScreen()),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.5, curve: Curves.easeOutBack),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    const colors = [
      (Palette.pink, Palette.pinkDeep),
      (Palette.sky, Palette.skyDeep),
      (Palette.mint, Palette.mintDeep),
      (Palette.peach, Palette.peachDeep),
      (Palette.lavender, Palette.lavenderDeep),
      (Palette.butter, Palette.butterDeep),
    ];
    Widget word(String w, int offset) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < w.length; i++)
              Builder(builder: (context) {
                final (light, deep) = colors[(i + offset) % colors.length];
                final idx = i + offset;
                return Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.all(4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(light, Colors.white, 0.3)!, light],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: softShadow(deep, blur: 12, y: 6, opacity: 0.45),
                  ),
                  child: Text(w[i], style: const TextStyle(fontFamily: kFont, fontSize: 36, color: Palette.ink)),
                )
                    .animate(delay: (idx * 70).ms)
                    .scaleXY(begin: 0, duration: 600.ms, curve: Curves.elasticOut)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -6, duration: (900 + idx * 60).ms, curve: Curves.easeInOut);
              }),
          ],
        );
    return Column(
      children: [
        word('NODE', 0),
        word('SWAP', 4),
      ],
    );
  }
}

/// 대칭 보드가 계속 바뀌며 반짝이는 데모.
class _DemoBoard extends StatefulWidget {
  const _DemoBoard({required this.size});

  final double size;

  @override
  State<_DemoBoard> createState() => _DemoBoardState();
}

class _DemoBoardState extends State<_DemoBoard> {
  final _gen = PuzzleGenerator();
  final _key = GlobalKey<BoardViewState>();
  late Board _board;
  late List<int> _ids;
  SymmetryType _type = SymmetryType.horizontal;
  int _serial = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _next();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) => _next());
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _type = SymmetryType.values[_serial % 3];
      _board = _gen.symmetricBoard(_type);
      _serial++;
      _ids = List.generate(Board.cellCount, (i) => i + _serial * 100);
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _key.currentState?.celebrate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SymmetryBadge(type: _type, compact: true),
        const SizedBox(height: 10),
        IgnorePointer(
          child: BoardView(
            key: _key,
            board: _board,
            tileIds: _ids,
            target: _type,
            size: widget.size,
            enabled: false,
            onTapCell: (_) {},
            onSwap: (_, _) {},
          ),
        ),
      ],
    );
  }
}
