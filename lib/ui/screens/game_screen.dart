import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/game_controller.dart';
import '../../game/game_state.dart';
import '../../game/logic/rules.dart';
import '../widgets/board_view.dart';
import '../widgets/bubbly.dart';
import '../widgets/fx_layer.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/particles.dart';
import '../widgets/pastel_background.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.mode, this.difficulty = Difficulty.normal});

  final GameMode mode;
  final Difficulty difficulty;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _boardKey = GlobalKey<BoardViewState>();
  final _particlesKey = GlobalKey<ParticleFieldState>();
  final _fxKey = GlobalKey<FxLayerState>();
  final _timerKey = GlobalKey();
  final _rotateKey = GlobalKey();
  final _scoreKey = GlobalKey();

  late final GameController _ctrl;
  StreamSubscription<GameEvent>? _sub;
  AppLifecycleListener? _lifecycle;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(gameProvider.notifier);
    _sub = _ctrl.events.listen(_onEvent);
    _lifecycle = AppLifecycleListener(onHide: _ctrl.pause, onPause: _ctrl.pause);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.start(widget.mode, difficulty: widget.difficulty);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _lifecycle?.dispose();
    final ctrl = _ctrl;
    Future.microtask(() {
      if (!_leaving) ctrl.quit();
    });
    super.dispose();
  }

  Offset _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  // ── 연출 ────────────────────────────────────────────────
  void _onEvent(GameEvent e) {
    if (!mounted) return;
    final fx = _fxKey.currentState;
    final particles = _particlesKey.currentState;
    final board = _boardKey.currentState;
    final s = ref.read(gameProvider);
    final (light, deep) = s == null ? (Palette.pink, Palette.pinkDeep) : Palette.forSymmetry(s.target);

    switch (e) {
      case CountdownTick(:final value):
        fx?.banner(
          value == 0 ? 'GO!' : '$value',
          color: value == 0 ? Palette.mintDeep : Palette.lavenderDeep,
          size: value == 0 ? 84 : 96,
          duration: const Duration(milliseconds: 580),
        );
      case SwapEvent(:final newlyMatched):
        if (newlyMatched.isNotEmpty) {
          board?.pulseCells(newlyMatched);
          for (final c in newlyMatched) {
            if (board != null) particles?.sparkle(board.cellCenterGlobal(c), deep);
          }
        }
      case InvalidSwapEvent(:final a, :final b):
        board?.nudge(a, b);
      case RotateEvent():
        if (board != null) particles?.ring(board.centerGlobal, light, size: 120);
      case ClearEvent(:final gain, :final timeBonusMs, :final combo, :final perfect, :final fast):
        board?.celebrate();
        if (board != null) {
          final c = board.centerGlobal;
          particles?.burst(c, count: 46, colors: [light, deep, Palette.butterDeep, Colors.white]);
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted) particles?.ring(c, deep, size: 150);
          });
          fx?.floatText('+${RollingNumber.formatInt(gain)}', c - const Offset(0, 40),
              color: deep, size: 40, rise: 110, duration: const Duration(milliseconds: 1100));
        }
        if (timeBonusMs > 0) {
          fx?.floatText('+${timeBonusMs ~/ 1000}초', _centerOf(_timerKey) + const Offset(60, 30),
              color: Palette.mintDeep, size: 24, rise: 40);
        }
        final String title;
        String? sub;
        if (widget.mode == GameMode.classic) {
          title = 'CLEAR!';
          sub = perfect ? 'PERFECT · 최소 이동!' : null;
        } else if (combo >= 2) {
          title = 'COMBO ×$combo';
          sub = perfect ? 'PERFECT!' : (fast ? 'FAST!' : null);
        } else {
          title = perfect ? 'PERFECT!' : (fast ? 'FAST!' : 'NICE!');
        }
        fx?.banner(title, sub: sub, color: combo >= 4 ? Palette.pinkDeep : deep, size: combo >= 4 ? 60 : 52);
      case FailEvent(:final reason, :final penaltyMs):
        board?.shake();
        final title = switch (reason) {
          FailReason.stuck => '막혔어요!',
          FailReason.outOfMoves => '이동 끝!',
          FailReason.skipped => '건너뛰기',
        };
        fx?.banner(
          title,
          sub: penaltyMs > 0 ? '−${penaltyMs ~/ 1000}초 · 새 퍼즐' : '다시 도전해 봐요',
          color: reason == FailReason.skipped ? Palette.skyDeep : Palette.danger,
          size: 48,
          duration: const Duration(milliseconds: 900),
        );
      case FeverEvent(:final started):
        if (started) {
          fx?.banner('FEVER TIME!',
              sub: '시간 정지 · 점수 2배', color: Palette.butterDeep, size: 58, duration: const Duration(milliseconds: 1500), dy: 0.25);
          particles?.confetti(count: 70);
        } else {
          fx?.floatText('피버 끝!', _centerOf(_timerKey), color: Palette.inkSoft, size: 20);
        }
      case NewPuzzleEvent():
        break;
      case HintEvent(:final hint):
        if (hint.rotate) {
          fx?.floatText('돌려 보세요!', _centerOf(_rotateKey) - const Offset(0, 30),
              color: Palette.lavenderDeep, size: 22);
        }
      case TimeUpEvent():
        fx?.banner('TIME UP!', color: Palette.danger, size: 64, duration: const Duration(milliseconds: 1500));
        if (board != null) particles?.burst(board.centerGlobal, count: 30, colors: [Palette.inkFaint, Palette.lavender]);
      case GameOverEvent():
        _scheduleResult();
    }
  }

  void _scheduleResult() {
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      final s = ref.read(gameProvider);
      if (s == null) return;
      _leaving = true;
      Navigator.of(context).pushReplacement(softRoute(ResultScreen(session: s)));
    });
  }

  // ── 화면 ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final fever = s?.isFever ?? false;
    final tint = s == null ? null : Palette.forSymmetry(s.target).$1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ctrl.pause();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PastelBackground(
          fever: fever,
          tint: tint,
          child: ParticleField(
            key: _particlesKey,
            child: FxLayer(
              key: _fxKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (fever) const _FeverFrame(),
                  SafeArea(
                    child: PhoneColumn(
                      child: s == null ? const SizedBox() : _content(s),
                    ),
                  ),
                  if (s != null && s.phase == Phase.paused) _PauseOverlay(ctrl: _ctrl, mode: widget.mode),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(GameSession s) {
    final (light, deep) = Palette.forSymmetry(s.target);
    return LayoutBuilder(builder: (context, c) {
      // c 는 좌우 패딩(16 × 2)을 빼기 전 크기다.
      final boardSize = min(c.maxWidth - 32 - 8, c.maxHeight * 0.56).clamp(220.0, 460.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            _topBar(s),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: _timerKey,
              child: TimerBar(
                fraction: s.timeFraction,
                remainingMs: s.remainingMs,
                fever: s.isFever,
                feverFraction: s.feverMs / Rules.feverDurationMs,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SymmetryBadge(type: s.target),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ComboChip(combo: s.combo, fever: s.isFever),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            BoardView(
              key: _boardKey,
              board: s.board,
              tileIds: s.tileIds,
              target: s.target,
              size: boardSize,
              selected: s.selected,
              hint: s.hint,
              rotations: s.rotations,
              enabled: s.canAct,
              dimmed: s.phase == Phase.over && !s.won,
              hideTiles: s.phase == Phase.paused,
              onTapCell: _ctrl.tapCell,
              onSwap: _ctrl.swap,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('남은 이동', style: TextStyles.caption.copyWith(fontSize: 15)),
                const SizedBox(width: 10),
                Flexible(child: MovesPips(used: s.movesUsed, max: s.maxMoves, color: deep)),
                const SizedBox(width: 10),
                Text('${s.movesLeft}', style: TextStyles.number.copyWith(fontSize: 22, color: deep)),
              ],
            ),
            const Spacer(),
            _controls(s, light, deep),
          ],
        ),
      );
    });
  }

  Widget _topBar(GameSession s) {
    return Row(
      children: [
        RoundIconButton(icon: Icons.pause_rounded, onPressed: s.canAct ? _ctrl.pause : null),
        const Spacer(),
        Column(
          key: _scoreKey,
          children: [
            Text(widget.mode == GameMode.rush ? 'SCORE' : '클래식 · ${widget.difficulty.label}',
                style: TextStyles.caption),
            RollingNumber(
              value: s.score,
              style: TextStyles.number.copyWith(fontSize: 34),
            ),
          ],
        ),
        const Spacer(),
        Pill(
          child: Column(
            children: [
              Text(widget.mode == GameMode.rush ? 'STAGE' : 'MOVES', style: TextStyles.caption.copyWith(fontSize: 11)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Text(
                  widget.mode == GameMode.rush ? '${s.stage}' : '${s.puzzle.par}',
                  key: ValueKey(s.stage),
                  style: TextStyles.number.copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controls(GameSession s, Color light, Color deep) {
    final rotateGlow = s.rotateToWin || (s.hint?.rotate ?? false);
    return Row(
      children: [
        Expanded(
          child: BubblyButton(
            label: '힌트',
            subtitle: '${s.hintsLeft}개 남음',
            icon: Icons.lightbulb_rounded,
            color: Palette.butter,
            deep: Palette.butterDeep,
            fontSize: 17,
            height: 74,
            vertical: true,
            sound: null,
            onPressed: s.canAct && s.hintsLeft > 0 && s.hint == null ? _ctrl.useHint : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: KeyedSubtree(
            key: _rotateKey,
            child: BubblyButton(
              label: '회전 90°',
              subtitle: '무료',
              icon: Icons.rotate_right_rounded,
              color: light,
              deep: deep,
              fontSize: 22,
              height: 74,
              glow: rotateGlow,
              sound: null,
              onPressed: s.canAct ? _ctrl.rotate : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: widget.mode == GameMode.rush
              ? BubblyButton(
                  label: '패스',
                  subtitle: '−3초',
                  icon: Icons.fast_forward_rounded,
                  color: Palette.sky,
                  deep: Palette.skyDeep,
                  fontSize: 17,
                  height: 74,
                  vertical: true,
                  sound: null,
                  onPressed: s.canAct ? _ctrl.skip : null,
                )
              : BubblyButton(
                  label: '다시',
                  subtitle: '새 퍼즐',
                  icon: Icons.refresh_rounded,
                  color: Palette.sky,
                  deep: Palette.skyDeep,
                  fontSize: 17,
                  height: 74,
                  vertical: true,
                  onPressed: s.canAct ? _ctrl.restart : null,
                ),
        ),
      ],
    );
  }
}

class _ComboChip extends StatelessWidget {
  const _ComboChip({required this.combo, required this.fever});

  final int combo;
  final bool fever;

  @override
  Widget build(BuildContext context) {
    final show = combo >= 2 || fever;
    final mult = Rules.comboMultiplier(max(1, combo), fever: fever);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: !show
          ? const SizedBox(key: ValueKey('none'), height: 36)
          : Container(
              key: ValueKey('$combo$fever'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: fever
                      ? const [Palette.butterDeep, Palette.pinkDeep]
                      : const [Palette.peach, Palette.pink],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: softShadow(Palette.pinkDeep, blur: 10, y: 4, opacity: 0.3),
              ),
              child: Text(
                fever ? 'FEVER ×${_fmtMult(mult)}' : '$combo COMBO ×${_fmtMult(mult)}',
                style: TextStyle(fontFamily: kFont, fontSize: 15, color: fever ? Colors.white : Palette.ink),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.06, duration: 450.ms),
    );
  }
}

String _fmtMult(double m) =>
    m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(m * 10 == (m * 10).roundToDouble() ? 1 : 2);

/// 피버 중 화면 가장자리가 무지개빛으로 빛난다.
class _FeverFrame extends StatefulWidget {
  const _FeverFrame();

  @override
  State<_FeverFrame> createState() => _FeverFrameState();
}

class _FeverFrameState extends State<_FeverFrame> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          decoration: BoxDecoration(
            border: GradientBoxBorder(
              gradient: SweepGradient(
                colors: [...Palette.fever, Palette.fever.first],
                transform: GradientRotation(_c.value * pi * 2),
              ),
              width: 8,
            ),
          ),
        ),
      ),
    );
  }
}

/// 그라디언트 테두리.
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({required this.gradient, this.width = 4});

  final Gradient gradient;
  final double width;

  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);
  @override
  bool get isUniform => true;

  @override
  void paint(Canvas canvas, Rect rect,
      {TextDirection? textDirection, BoxShape shape = BoxShape.rectangle, BorderRadius? borderRadius}) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(rect.deflate(width / 2), paint);
  }

  @override
  ShapeBorder scale(double t) => GradientBoxBorder(gradient: gradient, width: width * t);
}

class _PauseOverlay extends ConsumerWidget {
  const _PauseOverlay({required this.ctrl, required this.mode});

  final GameController ctrl;
  final GameMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Container(
      color: Palette.ink.withValues(alpha: 0.25),
      child: Center(
        child: PhoneColumn(
          maxWidth: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              opacity: 0.85,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('잠깐 쉬어요', style: TextStyles.title),
                  const SizedBox(height: 6),
                  Text('시간이 멈췄어요', style: TextStyles.caption),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Toggle(
                        icon: settings.musicVolume > 0 ? Icons.music_note_rounded : Icons.music_off_rounded,
                        label: '음악',
                        on: settings.musicVolume > 0,
                        onTap: () => notifier.setMusicVolume(settings.musicVolume > 0 ? 0 : 0.5),
                      ),
                      const SizedBox(width: 12),
                      _Toggle(
                        icon: settings.sfxVolume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        label: '효과음',
                        on: settings.sfxVolume > 0,
                        onTap: () => notifier.setSfxVolume(settings.sfxVolume > 0 ? 0 : 0.8),
                      ),
                      const SizedBox(width: 12),
                      _Toggle(
                        icon: Icons.vibration_rounded,
                        label: '진동',
                        on: settings.haptics,
                        onTap: () => notifier.setHaptics(!settings.haptics),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  BubblyButton(
                    label: '계속하기',
                    icon: Icons.play_arrow_rounded,
                    color: Palette.mint,
                    deep: Palette.mintDeep,
                    width: double.infinity,
                    onPressed: ctrl.resume,
                  ),
                  const SizedBox(height: 14),
                  BubblyButton(
                    label: '처음부터',
                    icon: Icons.replay_rounded,
                    color: Palette.sky,
                    deep: Palette.skyDeep,
                    width: double.infinity,
                    height: 52,
                    fontSize: 19,
                    onPressed: ctrl.restart,
                  ),
                  const SizedBox(height: 14),
                  BubblyButton(
                    label: '홈으로',
                    icon: Icons.home_rounded,
                    color: Palette.white,
                    deep: Palette.inkFaint,
                    width: double.infinity,
                    height: 52,
                    fontSize: 19,
                    onPressed: () {
                      ref.read(audioProvider).duck(false);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 180.ms).scaleXY(begin: 0.92, curve: Curves.easeOutBack),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? Palette.lavender : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: on ? Palette.ink : Palette.inkFaint),
            const SizedBox(height: 2),
            Text(label, style: TextStyles.caption.copyWith(color: on ? Palette.ink : Palette.inkSoft)),
          ],
        ),
      ),
    );
  }
}
