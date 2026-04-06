import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_model.dart';
import '../models/game_state.dart';
import '../providers/game_state_provider.dart';
import '../providers/hint_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/timer_provider.dart';
import '../widgets/combo_flash_widget.dart';
import '../widgets/game_board.dart';
import '../widgets/shake_widget.dart';
import '../widgets/symmetry_indicator.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late ConfettiController _confetti;
  final GlobalKey<GameBoardState> _boardKey = GlobalKey();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey();
  bool _hasShakenTime = false;
  bool _hasShakenMoves = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameStateProvider.notifier).startGame(
            Difficulty.easy,
            SymmetryType.horizontal,
          );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게임 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('난이도', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _DifficultySelector(),
            const SizedBox(height: 16),
            const Text('대칭 종류', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _SymmetrySelector(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final difficulty = ref.read(_selectedDifficulty);
              final symmetry = ref.read(symmetryProvider);
              _hasShakenTime = false;
              _hasShakenMoves = false;
              ref
                  .read(gameStateProvider.notifier)
                  .startGame(difficulty, symmetry);
            },
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final isMuted = ref.watch(soundProvider);

    // 승패 감지 → 결과 화면 이동
    ref.listen<GameState>(gameStateProvider, (prev, next) {
      if (prev?.phase == GamePhase.playing) {
        if (next.phase == GamePhase.won) {
          _confetti.play();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(gameState: next),
              ),
            );
          });
        } else if (next.phase == GamePhase.lost) {
          _shakeKey.currentState?.shake(amplitude: 2.0);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            Navigator.push(
              this.context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(gameState: next),
              ),
            );
          });
        }
      }

      // 시간 임박 진동
      if (prev?.isTimeCritical == false && next.isTimeCritical && !_hasShakenTime) {
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
        title: const Text(
          'Node Swap',
          style: TextStyle(fontWeight: FontWeight.bold),
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
            icon: const Icon(Icons.tune),
            tooltip: '게임 설정',
            onPressed: _showDifficultyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '리셋',
            onPressed: () {
              _hasShakenTime = false;
              _hasShakenMoves = false;
              ref.read(gameStateProvider.notifier).resetGame();
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ── 메인 컨텐츠 ──
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 상태 배지
              SymmetryStatusBadge(
                achieved: gameState.phase == GamePhase.won,
                type: gameState.targetSymmetry,
              ),
              const SizedBox(height: 12),

              // 보드 (ShakeWidget으로 감쌈)
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

          // ── 콤보 플래시 오버레이 ──
          const ComboFlashWidget(),

          // ── Confetti ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              colors: const [
                Colors.amber,
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 선택 난이도 임시 provider ──────────────────────────────────
final _selectedDifficulty = StateProvider<Difficulty>((_) => Difficulty.easy);

class _DifficultySelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedDifficulty);
    return SegmentedButton<Difficulty>(
      segments: const [
        ButtonSegment(value: Difficulty.easy, label: Text('Easy')),
        ButtonSegment(value: Difficulty.normal, label: Text('Normal')),
        ButtonSegment(value: Difficulty.hard, label: Text('Hard')),
      ],
      selected: {selected},
      onSelectionChanged: (s) =>
          ref.read(_selectedDifficulty.notifier).state = s.first,
    );
  }
}

class _SymmetrySelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(symmetryProvider);
    return SegmentedButton<SymmetryType>(
      segments: const [
        ButtonSegment(
            value: SymmetryType.horizontal, label: Text('좌우')),
        ButtonSegment(
            value: SymmetryType.vertical, label: Text('상하')),
        ButtonSegment(
            value: SymmetryType.pointSymmetry, label: Text('점')),
      ],
      selected: {selected},
      onSelectionChanged: (s) =>
          ref.read(symmetryProvider.notifier).state = s.first,
    );
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
        // 타이머 + 점수 행
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TimerDisplay(),
            const SizedBox(width: 24),
            _ScoreDisplay(score: gameState.score),
          ],
        ),
        const SizedBox(height: 8),
        // 이동 횟수 + 별점
        _MoveSection(gameState: gameState),
      ],
    );
  }
}

// ── 타이머 디스플레이 (gameTimerProvider만 구독) ──────────────
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

    // 틱 사운드
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
            Icon(
              Icons.timer,
              size: 18,
              color: timeColor,
            ),
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

// ── 점수 디스플레이 (롤업 효과) ────────────────────────────────
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

// ── 이동 횟수 섹션 ────────────────────────────────────────────
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
