import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/game_state.dart';
import '../../game/logic/board.dart';
import '../../game/logic/lessons.dart';
import '../../game/logic/rules.dart';
import '../../game/logic/solver.dart';
import '../widgets/board_view.dart';
import '../widgets/bubbly.dart';
import '../widgets/fx_layer.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/math_text.dart';
import '../widgets/particles.dart';
import '../widgets/pastel_background.dart';
import 'game_screen.dart';

/// 3단계로 직접 해 보는 튜토리얼.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key, this.then});

  /// 끝나면 바로 시작할 모드. null 이면 이전 화면으로 돌아간다.
  final GameMode? then;

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _boardKey = GlobalKey<BoardViewState>();
  final _particles = GlobalKey<ParticleFieldState>();
  final _fx = GlobalKey<FxLayerState>();

  int _step = 0;
  late Board _board;
  late List<int> _ids;
  int? _selected;
  int _rotations = 0;
  bool _solved = false;
  bool _done = false;

  Lesson get _lesson => lessons[_step];
  AudioEngine get _audio => ref.read(audioProvider);

  @override
  void initState() {
    super.initState();
    _load(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _audio.setMusic(Music.menu));
  }

  void _load(int step) {
    _step = step;
    _board = lessons[step].board;
    _ids = List.generate(Board.cellCount, (i) => i + step * 100);
    _selected = null;
    _rotations = 0;
    _solved = false;
  }

  Hint? get _hint {
    if (_solved || !_lesson.showHint) return null;
    final s = Solver(_lesson.target).solve(_board, maxDepth: 3);
    if (s == null || s.swaps.isEmpty) return null;
    final (a, b) = s.swaps.first;
    return Hint.swap(a, b);
  }

  void _tap(int cell) {
    if (_solved) return;
    if (_selected == null || _selected == cell) {
      setState(() => _selected = _selected == cell ? null : cell);
      _audio.play(Sfx.select);
    } else if (Board.isAdjacent(_selected!, cell)) {
      _swap(_selected!, cell);
    } else {
      setState(() => _selected = cell);
      _audio.play(Sfx.select);
    }
  }

  void _swap(int a, int b) {
    if (_solved) return;
    if (_board[a] == _board[b]) {
      _boardKey.currentState?.nudge(a, b);
      _audio.play(Sfx.error);
      setState(() => _selected = null);
      return;
    }
    final before = _board.matchedCells(_lesson.target);
    setState(() {
      _board = _board.swap(a, b);
      final t = _ids[a];
      _ids = List.of(_ids)
        ..[a] = _ids[b]
        ..[b] = t;
      _selected = null;
    });
    _audio.play(Sfx.swap);
    _audio.haptic(HapticKind.light);
    final newly = _board.matchedCells(_lesson.target).difference(before);
    if (newly.isNotEmpty) {
      _boardKey.currentState?.pulseCells(newly);
      _audio.play(Sfx.match((_board.symmetryProgress(_lesson.target) * 6).round()));
    }
    _check();
  }

  void _rotate() {
    if (_solved) return;
    final ids = List<int>.filled(Board.cellCount, 0);
    for (int i = 0; i < Board.cellCount; i++) {
      ids[Board.rotatedIndex(i)] = _ids[i];
    }
    setState(() {
      _board = _board.rotateCW();
      _ids = ids;
      _rotations++;
      _selected = null;
    });
    _audio.play(Sfx.rotate);
    _check();
  }

  void _check() {
    if (!_board.isSymmetric(_lesson.target)) {
      // 연습이라 실패는 없다. 너무 꼬이면 원래대로 돌려 준다.
      if (Solver(_lesson.target).solve(_board, maxDepth: 3) == null) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _fx.currentState?.banner('다시 해 볼까요?', color: Palette.skyDeep, size: 40);
          setState(() => _load(_step));
        });
      }
      return;
    }
    setState(() => _solved = true);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final board = _boardKey.currentState;
      board?.celebrate();
      if (board != null) _particles.currentState?.burst(board.centerGlobal, count: 40);
      _fx.currentState?.banner(_step == lessons.length - 1 ? '완벽해요!' : '잘했어요!',
          color: Palette.forSymmetry(_lesson.target).$2);
      _audio.play(Sfx.clear);
      _audio.haptic(HapticKind.medium);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_step + 1 < lessons.length) {
        setState(() => _load(_step + 1));
        _audio.play(Sfx.whoosh);
      } else {
        setState(() => _done = true);
        ref.read(settingsProvider.notifier).markTutorialSeen();
        _audio.play(Sfx.fanfare);
        _particles.currentState?.confetti();
      }
    });
  }

  void _finish() {
    final then = widget.then;
    if (then == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(softRoute(GameScreen(mode: then)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (light, deep) = Palette.forSymmetry(_lesson.target);
    return Scaffold(
      body: PastelBackground(
        tint: light,
        child: ParticleField(
          key: _particles,
          child: FxLayer(
            key: _fx,
            child: SafeArea(
              child: PhoneColumn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: _done ? _doneView() : _lessonView(light, deep),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lessonView(Color light, Color deep) {
    return LayoutBuilder(builder: (context, c) {
      final size = (c.maxWidth - 40).clamp(220.0, 400.0).toDouble();
      final boardSize = size > c.maxHeight * 0.5 ? c.maxHeight * 0.5 : size;
      return Column(
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
              const Spacer(),
              for (int i = 0; i < lessons.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _step ? 28 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: i <= _step ? deep : Palette.inkFaint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(settingsProvider.notifier).markTutorialSeen();
                  _finish();
                },
                child: Text('건너뛰기', style: TextStyles.caption.copyWith(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassCard(
            key: ValueKey(_step),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_step + 1}. ${_lesson.title}', style: TextStyles.title.copyWith(fontSize: 24)),
                  ],
                ),
                const SizedBox(height: 8),
                MathRichText(_lesson.body,
                    textAlign: TextAlign.center, style: TextStyles.body.copyWith(height: 1.45, color: Palette.inkSoft)),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.15, curve: Curves.easeOutBack),
          const SizedBox(height: 14),
          SymmetryBadge(type: _lesson.target),
          const Spacer(),
          BoardView(
            key: _boardKey,
            board: _board,
            tileIds: _ids,
            target: _lesson.target,
            size: boardSize,
            selected: _selected,
            hint: _hint,
            rotations: _rotations,
            enabled: !_solved,
            onTapCell: _tap,
            onSwap: _swap,
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: BubblyButton(
              label: '90도 회전',
              icon: Icons.rotate_right_rounded,
              color: light,
              deep: deep,
              glow: _lesson.focusRotate && !_solved,
              sound: null,
              onPressed: _solved ? null : _rotate,
            ),
          ),
        ],
      );
    });
  }

  Widget _doneView() {
    return Column(
      children: [
        const Spacer(),
        const Text('준비 완료!', style: TextStyles.display)
            .animate()
            .scaleXY(begin: 0.4, duration: 700.ms, curve: Curves.elasticOut),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            children: [
              _tip(Icons.timer_rounded, Palette.mintDeep, '러시 모드는 60초! 풀 때마다 시간이 늘어나요.'),
              _tip(Icons.bolt_rounded, Palette.pinkDeep, '8초 안에 연달아 풀면 콤보가 쌓여요.'),
              _tip(Icons.local_fire_department_rounded, Palette.butterDeep,
                  '${Rules.feverEvery}콤보마다 피버 타임! 시간이 멈추고 점수 2배.'),
              _tip(Icons.block_rounded, Palette.danger, '더 이상 풀 수 없으면 바로 다음 퍼즐로 넘어가요 (-4초).'),
              _tip(Icons.call_made_rounded, Palette.peachDeep, '6스테이지부터 {y = x}, {y = -x} 대칭도 나와요.'),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const Spacer(),
        BubblyButton(
          label: widget.then == null ? '좋아요!' : '러시 시작!',
          icon: Icons.bolt_rounded,
          color: Palette.pink,
          deep: Palette.pinkDeep,
          width: double.infinity,
          height: 70,
          fontSize: 26,
          glow: true,
          onPressed: _finish,
        ),
      ],
    );
  }

  Widget _tip(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(child: MathRichText(text, style: TextStyles.body.copyWith(fontSize: 15.5))),
          ],
        ),
      );
}
