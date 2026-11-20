import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/logic/board.dart';
import '../../game/logic/daily.dart';
import '../../online/leaderboard.dart';
import '../../game/logic/generator.dart';
import '../../game/logic/rules.dart';
import '../../game/logic/symmetry.dart';
import '../widgets/board_view.dart';
import '../widgets/bubbly.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/pastel_background.dart';
import 'game_screen.dart';
import 'ranking_screen.dart';
import 'stage_map_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioProvider).setMusic(Music.menu);
      // 예전에 못 올린 러시 점수가 있으면 다시 올린다.
      ref.read(scoreUploaderProvider).flush();
    });
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(softRoute(page));
    if (mounted) ref.read(audioProvider).setMusic(Music.menu, fade: const Duration(milliseconds: 900));
  }

  void _startRush() {
    final seen = ref.read(settingsProvider).tutorialSeen;
    _go(seen ? const GameScreen(mode: GameMode.rush) : const TutorialScreen(then: GameMode.rush));
  }

  /// 오늘의 퍼즐: 날짜마다 같은 퍼즐 한 판 (클래식 규칙).
  void _openDaily() {
    final now = clock.now();
    _go(GameScreen(
      mode: GameMode.classic,
      boardSize: dailySize(now),
      puzzle: dailyPuzzle(now),
      dailyKey: dailyKey(now),
    ));
  }

  Future<void> _openClassic() async {
    final d = await showClassicSheet(context);
    if (d != null && mounted) _go(StageMapScreen(boardSize: d));
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final daily = ref.watch(dailyProgressProvider);
    final now = clock.now();
    final today = dailyKey(now);
    final streak = daily.streakOn(today, dailyYesterdayKey(now));
    final dailyText = daily.clearedOn(today)
        ? '오늘 완료!  $streak일 연속'
        : streak > 0
            ? '${dailySize(now).label}  |  $streak일 연속 도전 중'
            : '${dailySize(now).label}  |  매일 새로운 한 판';
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
                        if (ref.watch(leaderboardProvider).available) ...[
                          RoundIconButton(
                            icon: Icons.emoji_events_rounded,
                            color: Palette.butter,
                            deep: Palette.butterDeep,
                            onPressed: () => _go(const RankingScreen()),
                          ),
                          const Spacer(),
                        ],
                        RoundIconButton(
                          icon: Icons.settings_rounded,
                          onPressed: () => showSettingsSheet(context),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const _Logo(),
                    const SizedBox(height: 10),
                    Text('밀고, 돌리고, 대칭을 완성하세요!',
                            style: TextStyles.body.copyWith(color: Palette.inkSoft, fontSize: 17))
                        .animate()
                        .fadeIn(delay: 700.ms),
                    const Spacer(),
                    _DemoBoard(size: demo),
                    const Spacer(),
                    BubblyButton(
                      label: '러시 시작',
                      subtitle: records.rushBestScore > 0
                          ? '최고 ${RollingNumber.formatInt(records.rushBestScore)}점 (${records.rushBestStage}번째 퍼즐)'
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
                            label: '스테이지',
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
                    const SizedBox(height: 12),
                    BubblyButton(
                      label: '오늘의 퍼즐',
                      subtitle: dailyText,
                      icon: daily.clearedOn(today) ? Icons.check_circle_rounded : Icons.today_rounded,
                      color: Palette.butter,
                      deep: Palette.butterDeep,
                      width: double.infinity,
                      height: 60,
                      fontSize: 20,
                      onPressed: _openDaily,
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5, curve: Curves.easeOutBack),
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

  // SYMMETRY: 양 끝에서 가운데로 색이 대칭이 되게 배치 (게임 주제를 로고에도)
  static const _symColors = [
    (Palette.pink, Palette.pinkDeep),
    (Palette.sky, Palette.skyDeep),
    (Palette.mint, Palette.mintDeep),
    (Palette.lavender, Palette.lavenderDeep),
  ];

  // RUSH: 속도감 있는 따뜻한 색
  static const _rushColors = [
    (Palette.pink, Palette.pinkDeep),
    (Palette.peach, Palette.peachDeep),
    (Palette.butter, Palette.butterDeep),
    (Palette.peach, Palette.peachDeep),
  ];

  Widget _tile(String ch, double size, (Color, Color) color, int order, {double tilt = 0}) {
    final (light, deep) = color;
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.all(size * 0.07),
      alignment: Alignment.center,
      transform: Matrix4.rotationZ(tilt),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(light, Colors.white, 0.3)!, light],
        ),
        borderRadius: BorderRadius.circular(size * 0.31),
        border: Border.all(color: Colors.white, width: size * 0.045),
        boxShadow: softShadow(deep, blur: size * 0.2, y: size * 0.1, opacity: 0.45),
      ),
      child: Text(ch, style: TextStyle(fontFamily: kFont, fontSize: size * 0.62, color: Palette.ink)),
    )
        .animate(delay: (order * 60).ms)
        .scaleXY(begin: 0, duration: 600.ms, curve: Curves.elasticOut)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -size * 0.1, duration: (900 + order * 50).ms, curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const sym = 'SYMMETRY';
      const rush = 'RUSH';
      // 8글자가 한 줄에 들어가도록 화면 너비에 맞춘다 (여백 = 타일의 7% × 2)
      final small = (c.maxWidth / (sym.length * 1.14)).clamp(28.0, 48.0);
      final big = (small * 1.55).clamp(40.0, 70.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < sym.length; i++)
                _tile(sym[i], small, _symColors[min(i, sym.length - 1 - i)], i),
            ],
          ),
          SizedBox(height: small * 0.1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < rush.length; i++)
                _tile(rush[i], big, _rushColors[i], sym.length + i, tilt: i.isEven ? -0.06 : 0.06),
            ],
          ),
        ],
      );
    });
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
    _next(first: true);
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) => _next());
  }

  void _next({bool first = false}) {
    if (!mounted) return;
    // 게임 화면이 위에 떠 있는 동안에는 데모를 멈춘다 (뒤에서 계속 돌면 낭비).
    if (!first && !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    setState(() {
      _type = SymmetryType.values[_serial % SymmetryType.values.length];
      _board = _gen.symmetricBoard(_type);
      _serial++;
      _ids = List.generate(_board.cellCount, (i) => i + _serial * 100);
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
