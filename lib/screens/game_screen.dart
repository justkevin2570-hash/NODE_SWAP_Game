import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/level_config.dart';
import '../data/level_data.dart';
import '../providers/game_state_provider.dart';
import '../providers/hint_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/timer_provider.dart';
import '../widgets/game_board.dart';
import '../widgets/shake_widget.dart';
import '../widgets/symmetry_indicator.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final LevelConfig config;

  const GameScreen({super.key, required this.config});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final GlobalKey<GameBoardState> _boardKey = GlobalKey();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey();
  bool _hasShakenTime = false;
  bool _hasShakenMoves = false;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameStateProvider.notifier).startGame(widget.config);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final isMuted = ref.watch(soundProvider);

    // 승패 감지 → 결과 화면 이동
    ref.listen<GameState>(gameStateProvider, (prev, next) async {
      if (prev?.phase == GamePhase.playing) {
        if (next.phase == GamePhase.won) {
          setState(() => _showClear = true);
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                gameState: next,
                levelConfig: widget.config,
              ),
            ),
          );
          if (!mounted) return;
          _handleResultAction(result);
        } else if (next.phase == GamePhase.lost) {
          _shakeKey.currentState?.shake(amplitude: 2.0);
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          final result = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                gameState: next,
                levelConfig: widget.config,
              ),
            ),
          );
          if (!mounted) return;
          _handleResultAction(result);
        }
      }

      // 시간 임박 진동
      if (prev?.isTimeCritical == false &&
          next.isTimeCritical &&
          !_hasShakenTime) {
        _hasShakenTime = true;
        _shakeKey.currentState?.shake();
      }
      // 이동 80% 초과 진동
      if ((prev?.moveProgress ?? 0) < 0.8 &&
          next.moveProgress >= 0.8 &&
          !_hasShakenMoves) {
        _hasShakenMoves = true;
        _shakeKey.currentState?.shake();
      }
      // 게임 리셋 시 플래그 초기화
      if (next.moveCount == 0 && next.phase == GamePhase.playing) {
        _hasShakenTime = false;
        _hasShakenMoves = false;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        title: Text(
          'Ep.${widget.config.episode}  Level ${widget.config.level}'
          '${widget.config.isFinalBoss ? " 👑" : widget.config.isMidBoss ? " ⚔️" : ""}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // 음소거 버튼
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: isMuted ? '소리 켜기' : '소리 끄기',
            onPressed: () =>
                ref.read(soundProvider.notifier).toggleMute(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '리셋',
            onPressed: () {
              _hasShakenTime = false;
              _hasShakenMoves = false;
              setState(() => _showClear = false);
              ref.read(gameStateProvider.notifier).resetGame();
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 대칭 타입 배지
              SymmetryStatusBadge(
                achieved: gameState.phase == GamePhase.won,
                type: gameState.targetSymmetry,
              ),
              const SizedBox(height: 12),

              // 보드
              ShakeWidget(
                key: _shakeKey,
                child: GameBoard(key: _boardKey),
              ),
              const SizedBox(height: 20),

              // HUD
              _GameHud(gameState: gameState),
              const SizedBox(height: 16),

              // 버튼 행
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: gameState.phase == GamePhase.playing
                        ? () => _boardKey.currentState?.triggerRotation()
                        : null,
                    icon: const Icon(Icons.rotate_right),
                    label: const Text('회전 90°'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3949AB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: gameState.canHint
                        ? () {
                            ref.read(hintProvider.notifier).computeHint();
                            ref.read(gameStateProvider.notifier).useHint();
                            Future.delayed(const Duration(seconds: 2), () {
                              ref.read(hintProvider.notifier).clearHint();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text('힌트 (${gameState.hintsRemaining})'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // CLEAR! 오버레이
          if (_showClear)
            const Center(child: _ClearOverlay()),
        ],
      ),
    );
  }

  void _handleResultAction(String? result) {
    switch (result) {
      case 'retry':
        setState(() => _showClear = false);
        ref.read(gameStateProvider.notifier).resetGame();
      case 'next':
        final nextConfig = LevelData.getNextLevel(widget.config);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(config: nextConfig)),
        );
      case 'levels':
        Navigator.pop(context);
      default:
        // result == null: 뒤로가기로 닫은 경우
        break;
    }
  }
}

// ── 통합 HUD ──────────────────────────────────────────────────
class _GameHud extends StatelessWidget {
  final GameState gameState;

  const _GameHud({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimerDisplay(),
            const SizedBox(width: 24),
            _ScoreDisplay(score: gameState.score),
          ],
        ),
        const SizedBox(height: 8),
        _MoveSection(gameState: gameState),
      ],
    );
  }
}

// ── 타이머 디스플레이 ──────────────────────────────────────────
class _TimerDisplay extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends ConsumerState<_TimerDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  int _prevSecs = -1;
  bool _ticking = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updatePulse(int secs) {
    if (secs <= 5 && !_ticking) {
      _ticking = true;
      _pulseCtrl.duration = const Duration(milliseconds: 300);
      _pulseCtrl.repeat(reverse: true);
    } else if (secs <= 10 && secs > 5 && !_ticking) {
      _ticking = true;
      _pulseCtrl.duration = const Duration(milliseconds: 500);
      _pulseCtrl.repeat(reverse: true);
    } else if (secs > 10 && _ticking) {
      _ticking = false;
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0;
    }

    if (secs != _prevSecs && secs > 0) {
      if (secs <= 5) {
        ref.read(soundProvider.notifier).play(SoundEvent.tickFast);
      } else if (secs <= 10) {
        ref.read(soundProvider.notifier).play(SoundEvent.tick);
      }
    }
    _prevSecs = secs;
  }

  @override
  Widget build(BuildContext context) {
    final secs = ref.watch(gameTimerProvider);
    final gamePhase = ref.watch(gameStateProvider.select((s) => s.phase));

    _updatePulse(secs);

    final mins = secs ~/ 60;
    final s = secs % 60;
    final timeStr =
        mins > 0 ? '$mins:${s.toString().padLeft(2, '0')}' : '$s';

    Color timeColor;
    if (secs <= 5) {
      timeColor = Colors.red;
    } else if (secs <= 10) {
      timeColor = Colors.orange;
    } else {
      timeColor = Colors.grey.shade700;
    }

    if (gamePhase != GamePhase.playing) {
      if (_ticking) {
        _ticking = false;
        _pulseCtrl.stop();
      }
    }

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context2, child2) => Transform.scale(
        scale: secs <= 10 ? _pulseAnim.value : 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, size: 18, color: timeColor),
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: timeColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 점수 디스플레이 ─────────────────────────────────────────────
class _ScoreDisplay extends StatelessWidget {
  final int score;

  const _ScoreDisplay({required this.score});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: score),
      duration: const Duration(milliseconds: 300),
      builder: (context2, val, child2) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 16, color: Colors.amber.shade600),
          const SizedBox(width: 4),
          Text(
            _formatScore(val),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000) {
      return '${(s ~/ 1000)},${(s % 1000).toString().padLeft(3, '0')}';
    }
    return '$s';
  }
}

// ── 이동 횟수 섹션 ─────────────────────────────────────────────
class _MoveSection extends StatelessWidget {
  final GameState gameState;

  const _MoveSection({required this.gameState});

  Color _starColor(int threshold) {
    final ratio = gameState.moveCount / gameState.maxMoves;
    if (ratio <= threshold / 3.0) return Colors.amber;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${gameState.moveCount} / ${gameState.maxMoves} 이동',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: gameState.moveProgress > 0.8
                ? Colors.red
                : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: _starColor(1), size: 20),
            Icon(Icons.star, color: _starColor(2), size: 20),
            Icon(Icons.star, color: _starColor(3), size: 20),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: gameState.moveProgress,
            backgroundColor: Colors.grey.shade200,
            color: gameState.moveProgress > 0.8
                ? Colors.red
                : const Color(0xFF3949AB),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

// ── CLEAR! 오버레이 ────────────────────────────────────────────
class _ClearOverlay extends StatefulWidget {
  const _ClearOverlay();

  @override
  State<_ClearOverlay> createState() => _ClearOverlayState();
}

class _ClearOverlayState extends State<_ClearOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.3, end: 1.15)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.15, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_ctrl);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3949AB).withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Text(
              'CLEAR!',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
