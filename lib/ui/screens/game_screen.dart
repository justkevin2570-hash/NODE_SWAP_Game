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
import '../../game/logic/generator.dart';
import '../../game/logic/rules.dart';
import '../widgets/board_view.dart';
import '../widgets/bubbly.dart';
import '../widgets/fx_layer.dart';
import '../widgets/hud.dart';
import '../widgets/layout.dart';
import '../widgets/particles.dart';
import '../widgets/pastel_background.dart';
import 'result_screen.dart';
import '../../core/l10n.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen(
      {super.key, required this.mode, this.boardSize = BoardSize.five, this.stage, this.puzzle, this.dailyKey});

  /// 오늘의 퍼즐이면 그 날짜 키 ([puzzle] 과 함께 준다).
  final String? dailyKey;

  final GameMode mode;
  final BoardSize boardSize;

  /// 클래식에서 같은 퍼즐을 다시 할 때 그 퍼즐.
  final Puzzle? puzzle;

  /// 클래식 스테이지 번호 (1~100).
  final int? stage;

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
    _lifecycle = AppLifecycleListener(
      // 포커스만 잃어도(화면 분할, 알림창) 일시정지. 자리 비움 시간은 화면에서 사라졌을 때부터 잰다.
      onInactive: _ctrl.pause,
      onHide: _ctrl.appHidden,
      onPause: _ctrl.appHidden,
      onShow: _ctrl.appShown,
      onResume: _ctrl.appShown,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.start(widget.mode,
          boardSize: widget.boardSize, stage: widget.stage, puzzle: widget.puzzle, dailyKey: widget.dailyKey);
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
      case StuckEvent():
        board?.shake();
        fx?.banner(
          tr('막혔어요!'),
          sub: widget.mode == GameMode.rush ? tr('되돌리기로 한 수 무르거나 패스하세요') : tr('되돌리기로 한 수 물러 보세요'),
          color: Palette.danger,
          size: 46,
          duration: const Duration(milliseconds: 1300),
        );
      case UndoEvent():
        if (board != null) particles?.ring(board.centerGlobal, light, size: 90);
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
          fx?.floatText(tr('+{n}초', {'n': timeBonusMs ~/ 1000}), _centerOf(_timerKey) + const Offset(60, 30),
              color: Palette.mintDeep, size: 24, rise: 40);
        }
        final String title;
        String? sub;
        if (widget.mode == GameMode.classic) {
          title = 'CLEAR!';
          sub = perfect ? tr('PERFECT! 최소 이동') : null;
        } else if (combo >= 2) {
          title = 'COMBO x$combo';
          sub = perfect ? 'PERFECT!' : (fast ? 'FAST!' : null);
        } else {
          title = perfect ? 'PERFECT!' : (fast ? 'FAST!' : 'NICE!');
        }
        fx?.banner(title, sub: sub, color: combo >= 4 ? Palette.pinkDeep : deep, size: combo >= 4 ? 60 : 52);
      case FailEvent(:final reason, :final penaltyMs):
        board?.shake();
        final title = switch (reason) {
          FailReason.stuck => tr('막혔어요!'),
          FailReason.outOfMoves => tr('이동 끝!'),
          FailReason.skipped => tr('건너뛰기'),
        };
        fx?.banner(
          title,
          sub: penaltyMs > 0 ? tr('-{n}초, 새 퍼즐', {'n': penaltyMs ~/ 1000}) : tr('다시 도전해 봐요'),
          color: reason == FailReason.skipped ? Palette.skyDeep : Palette.danger,
          size: 48,
          duration: const Duration(milliseconds: 900),
        );
      case FeverEvent(:final started):
        if (started) {
          fx?.banner('FEVER TIME!',
              sub: tr('시간 정지 + 점수 2배'), color: Palette.butterDeep, size: 58, duration: const Duration(milliseconds: 1500), dy: 0.25);
          particles?.confetti(count: 70);
        } else {
          fx?.floatText(tr('피버 끝!'), _centerOf(_timerKey), color: Palette.inkSoft, size: 20);
        }
      case NewPuzzleEvent():
        break;
      case HintEvent(:final hint):
        if (hint.rotate) {
          fx?.floatText(tr('돌려 보세요!'), _centerOf(_rotateKey) - const Offset(0, 30),
              color: Palette.lavenderDeep, size: 22);
        }
      case SessionExpiredEvent():
        fx?.banner(tr('오래 자리를 비웠어요'),
            sub: tr('이번 판은 여기까지! 점수는 기록에 남아요'),
            color: Palette.skyDeep,
            size: 40,
            duration: const Duration(milliseconds: 1600));
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
  /// 화면을 다시 그려야 하는 값들. 남은 시간처럼 50ms 마다 바뀌는 값은 빼서,
  /// 시간이 흐를 때마다 보드·버튼 전체가 다시 빌드되지 않게 한다 (시간 막대만 따로 갱신).
  static Object? _viewKey(GameSession? s) => s == null
      ? null
      : (
          s.puzzle,
          s.board,
          s.tileIds,
          s.phase,
          s.selected,
          s.hint,
          s.rotations,
          s.movesUsed,
          s.score,
          (s.combo, s.cleared, s.hintsLeft, s.isFever, s.won, s.puzzleSerial),
          (s.undosLeft, s.canUndoMove, s.stuck),
        );

  @override
  Widget build(BuildContext context) {
    ref.watch(gameProvider.select(_viewKey));
    final s = ref.read(gameProvider);
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
                  if (s != null && s.phase == Phase.paused) _PauseOverlay(ctrl: _ctrl, mode: widget.mode, daily: s.isDaily),
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
    final pairPreview = ref.watch(settingsProvider.select((st) => st.pairPreview));
    return LayoutBuilder(builder: (context, c) {
      // c 는 좌우 패딩(16 × 2)을 빼기 전 크기다.
      // 큰 판(7×7·9×9)은 타일이 너무 작아지지 않게 좌우 여백과 세로 비율을 조금 더 쓴다.
      final big = s.board.size > 5;
      final boardSize = min(c.maxWidth - 32 - (big ? 0 : 8), c.maxHeight * (big ? 0.6 : 0.56)).clamp(220.0, 520.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            _topBar(s),
            const SizedBox(height: 14),
            KeyedSubtree(key: _timerKey, child: const _LiveTimerBar()),
            const SizedBox(height: 14),
            Row(
              children: [
                // 자리가 모자라면(콤보·피버 표시) 대칭 칩과 콤보 칩이 함께 조금씩 줄어든다.
                Flexible(
                  flex: 3,
                  child: FittedBox(fit: BoxFit.scaleDown, child: SymmetryBadge(type: s.target)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ComboChip(combo: s.combo, fever: s.isFever),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 손해가 있는 버튼(패스 -3초, 새 퍼즐)은 엄지가 잘 닿지 않는 위쪽에 작게 둔다.
                _corner(s),
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
              // 짝 칸 표시는 클래식·오늘의 퍼즐에서만 (러시는 스스로 찾는 재미를 남긴다)
              pairCell: pairPreview && s.mode != GameMode.rush && s.selected != null
                  ? s.board.grid.partnerOf(s.target, s.selected!)
                  : null,
              hint: s.hint,
              rotations: s.rotations,
              enabled: s.canAct && !s.stuck,
              dimmed: s.phase == Phase.over && !s.won,
              hideTiles: s.phase == Phase.paused,
              onTapCell: _ctrl.tapCell,
              onSwap: _ctrl.swap,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('남은 이동'), style: TextStyles.caption.copyWith(fontSize: 15)),
                const SizedBox(width: 10),
                Flexible(child: MovesPips(used: s.movesUsed, max: s.maxMoves, color: deep, light: light)),
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
            Text(
                widget.mode == GameMode.rush
                    ? 'SCORE'
                    : s.isDaily
                        ? tr('오늘의 퍼즐 {size}', {'size': widget.boardSize.label})
                        : tr('{size} {n}탄', {'size': widget.boardSize.label, 'n': s.stageNumber ?? ''}),
                style: TextStyles.caption),
            if (widget.mode == GameMode.rush)
              RollingNumber(
                value: s.score,
                style: TextStyles.number.copyWith(fontSize: 34),
              )
            else
              // 스테이지: 점수 대신 지금 받을 수 있는 별 (헛수를 두면 하나씩 꺼진다)
              _StarPreview(
                stars: s.bestTotal == null
                    ? 3
                    : Rules.classicStars(movesUsed: s.bestTotal!, par: s.puzzle.par),
              ),
          ],
        ),
        const Spacer(),
        Pill(
          child: Column(
            children: [
              Text(widget.mode == GameMode.rush ? 'PUZZLE' : 'MOVES', style: TextStyles.caption.copyWith(fontSize: 11)),
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

  /// 위쪽 작은 버튼: 러시는 패스(-3초), 클래식은 새 퍼즐.
  /// 평소엔 눈에 덜 띄는 흰 보조 버튼, 막혔을 때만 산호색으로 반짝인다.
  /// (항상 같은 색이면 상하 대칭 판의 하늘색 테마와 겹치고, 손해 버튼이 주요 버튼처럼 보인다.)
  Widget _corner(GameSession s) {
    final rush = widget.mode == GameMode.rush;
    final stuck = s.stuck;
    return BubblyButton(
      label: rush ? tr('패스 -3초') : (s.isDaily ? tr('나가기') : tr('목록')),
      icon: rush ? Icons.fast_forward_rounded : (s.isDaily ? Icons.home_rounded : Icons.grid_view_rounded),
      color: stuck ? Palette.coral : Palette.white,
      deep: stuck ? Palette.coralDeep : Palette.inkFaint,
      labelColor: stuck ? Palette.ink : Palette.inkSoft,
      height: 40,
      width: 112,
      fontSize: 14,
      glow: stuck,
      sound: rush ? null : Sfx.button,
      onPressed: s.canAct ? (rush ? _ctrl.skip : () => Navigator.of(context).pop()) : null,
    );
  }

  /// 하단: [되돌리기] [90도 회전] [힌트]. 가장 자주 쓰는 회전을 가운데에 크게, 양옆은 같은 크기로 대칭.
  Widget _controls(GameSession s, Color light, Color deep) {
    final rotateGlow = s.rotateToWin || (s.hint?.rotate ?? false);
    return Row(
      children: [
        Expanded(
          child: BubblyButton(
            label: tr('되돌리기'),
            subtitle: tr('{n}개 남음', {'n': s.undosLeft}),
            icon: Icons.undo_rounded,
            color: Palette.peach,
            deep: Palette.peachDeep,
            fontSize: 17,
            height: 74,
            vertical: true,
            glow: s.stuck && s.canUndo,
            sound: null,
            onPressed: s.canUndo ? _ctrl.undo : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: KeyedSubtree(
            key: _rotateKey,
            child: BubblyButton(
              label: tr('90도 회전'),
              subtitle: tr('무료'),
              icon: Icons.rotate_right_rounded,
              color: light,
              deep: deep,
              fontSize: 22,
              height: 74,
              glow: rotateGlow && !s.stuck,
              sound: null,
              onPressed: s.canAct && !s.stuck ? _ctrl.rotate : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: BubblyButton(
            label: tr('힌트'),
            subtitle: tr('{n}개 남음', {'n': s.hintsLeft}),
            icon: Icons.lightbulb_rounded,
            color: Palette.butter,
            deep: Palette.butterDeep,
            fontSize: 17,
            height: 74,
            vertical: true,
            sound: null,
            onPressed: s.canAct && !s.stuck && s.hintsLeft > 0 && s.hint == null ? _ctrl.useHint : null,
          ),
        ),
      ],
    );
  }

}

/// 남은 시간만 구독해서 자기 자신만 다시 그리는 시간 막대.
class _LiveTimerBar extends ConsumerWidget {
  const _LiveTimerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 게임 시계는 50ms 마다 바뀌지만, 막대는 0.1초 단위면 충분하다.
    final t = ref.watch(gameProvider.select((s) => s == null
        ? null
        : (s.remainingMs ~/ 100, s.timeCapMs, s.isFever, s.feverMs ~/ 100)));
    if (t == null) return const SizedBox(height: 24);
    final (tenths, cap, fever, feverTenths) = t;
    final remainingMs = tenths * 100;
    return TimerBar(
      fraction: (remainingMs / cap).clamp(0.0, 1.0),
      remainingMs: remainingMs,
      fever: fever,
      feverFraction: (feverTenths * 100 / Rules.feverDurationMs).clamp(0.0, 1.0),
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
                fever ? 'FEVER x${_fmtMult(mult)}' : '$combo COMBO x${_fmtMult(mult)}',
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
  const _PauseOverlay({required this.ctrl, required this.mode, this.daily = false});

  final GameController ctrl;
  final GameMode mode;
  final bool daily;

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
                  Text(tr('잠깐 쉬어요'), style: TextStyles.title),
                  const SizedBox(height: 6),
                  Text(tr('시간이 멈췄어요'), style: TextStyles.caption),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Toggle(
                        icon: settings.musicVolume > 0 ? Icons.music_note_rounded : Icons.music_off_rounded,
                        label: tr('음악'),
                        on: settings.musicVolume > 0,
                        onTap: () => notifier.setMusicVolume(settings.musicVolume > 0 ? 0 : 0.5),
                      ),
                      const SizedBox(width: 12),
                      _Toggle(
                        icon: settings.sfxVolume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        label: tr('효과음'),
                        on: settings.sfxVolume > 0,
                        onTap: () => notifier.setSfxVolume(settings.sfxVolume > 0 ? 0 : 0.8),
                      ),
                      const SizedBox(width: 12),
                      _Toggle(
                        icon: Icons.vibration_rounded,
                        label: tr('진동'),
                        on: settings.haptics,
                        onTap: () => notifier.setHaptics(!settings.haptics),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  BubblyButton(
                    label: tr('계속하기'),
                    icon: Icons.play_arrow_rounded,
                    color: Palette.mint,
                    deep: Palette.mintDeep,
                    width: double.infinity,
                    onPressed: ctrl.resume,
                  ),
                  const SizedBox(height: 14),
                  BubblyButton(
                    label: tr('처음부터'),
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
                    label: mode == GameMode.classic && !daily ? tr('스테이지 목록') : tr('홈으로'),
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
    // 좁은 화면(360dp)에서도 세 개가 한 줄에 들어가도록 줄어들 수 있게 한다 (최대 82).
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 82),
        child: _box(),
      ),
    );
  }

  Widget _box() {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyles.caption.copyWith(color: on ? Palette.ink : Palette.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 스테이지에서 지금 받을 수 있는 별 개수. 줄어들 때 살짝 튀며 꺼진다.
class _StarPreview extends StatelessWidget {
  const _StarPreview({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            AnimatedScale(
              key: ValueKey('star$i'),
              scale: i < stars ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.star_rounded,
                size: 32,
                color: i < stars ? Palette.butterDeep : Palette.inkFaint.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}
