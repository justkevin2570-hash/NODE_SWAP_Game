import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/board_provider.dart';
import '../providers/game_state_provider.dart';
import '../providers/hint_provider.dart';
import 'tile_widget.dart';
import 'symmetry_indicator.dart';

const double _tileSize = 52.0;
const double _tileMargin = 3.0;
const double _tileStep = _tileSize + _tileMargin * 2;

class _SwapAnim {
  final int r1, c1, r2, c2;
  final AnimationController controller;
  final Offset startPos1, startPos2;

  _SwapAnim({
    required this.r1,
    required this.c1,
    required this.r2,
    required this.c2,
    required this.controller,
    required this.startPos1,
    required this.startPos2,
  });
}

class GameBoard extends ConsumerStatefulWidget {
  const GameBoard({super.key});

  @override
  ConsumerState<GameBoard> createState() => GameBoardState();
}

// public state so GameScreen can call triggerRotation() via GlobalKey
class GameBoardState extends ConsumerState<GameBoard>
    with TickerProviderStateMixin {
  double _turns = 0.0;
  bool _isRotating = false;
  _SwapAnim? _activeSwap;

  // GlobalKey for each tile position to look up RenderBox
  final Map<String, GlobalKey> _tileKeys = {
    for (int r = 0; r < 5; r++)
      for (int c = 0; c < 5; c++) '$r,$c': GlobalKey(),
  };

  void _onRotateComplete() {
    _isRotating = false;
  }

  void triggerRotation() {
    if (_isRotating) return;
    _isRotating = true;
    setState(() {
      _turns += 0.25;
    });
    ref.read(gameStateProvider.notifier).rotateBoard();
  }

  void _triggerSwapAnimation(int r1, int c1, int r2, int c2) {
    final key1 = _tileKeys['$r1,$c1'];
    final key2 = _tileKeys['$r2,$c2'];
    if (key1 == null || key2 == null) return;

    final box1 = key1.currentContext?.findRenderObject() as RenderBox?;
    final box2 = key2.currentContext?.findRenderObject() as RenderBox?;
    if (box1 == null || box2 == null) return;

    final pos1 = box1.localToGlobal(Offset.zero);
    final pos2 = box2.localToGlobal(Offset.zero);

    final ctrl = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    final swap = _SwapAnim(
      r1: r1,
      c1: c1,
      r2: r2,
      c2: c2,
      controller: ctrl,
      startPos1: pos1,
      startPos2: pos2,
    );

    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _activeSwap = null);
        ctrl.dispose();
      }
    });

    setState(() => _activeSwap = swap);
    ctrl.forward();
  }

  @override
  void dispose() {
    _activeSwap?.controller.dispose();
    super.dispose();
  }

  Widget _buildGhostTile(int value, bool isWon) {
    final Color fillColor =
        value == 1 ? const Color(0xFF1A237E) : const Color(0xFFE8EAF6);
    final Color borderColor = value == 1
        ? const Color(0xFF3949AB)
        : const Color(0xFFBDBDBD);
    return Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          value == 1 ? Icons.circle : Icons.circle_outlined,
          color: value == 1
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.15),
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    final gameState = ref.watch(gameStateProvider);
    final hintNotifier = ref.read(hintProvider.notifier);
    final isWon = gameState.phase.name == 'won';

    // 스왑 이벤트 구독
    ref.listen<(int, int, int, int)?>(swapAnimationProvider, (_, swap) {
      if (swap != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerSwapAnimation(swap.$1, swap.$2, swap.$3, swap.$4);
          // 이벤트 소비 후 null로 리셋
          ref.read(swapAnimationProvider.notifier).state = null;
        });
      }
    });

    const double boardSize = 5 * _tileStep;
    final swp = _activeSwap;

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedRotation(
          turns: _turns,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          onEnd: _onRotateComplete,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isWon
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: isWon ? 20 : 10,
                  spreadRadius: isWon ? 4 : 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (r) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (c) {
                    final isAnimating = swp != null &&
                        ((swp.r1 == r && swp.c1 == c) ||
                            (swp.r2 == r && swp.c2 == c));
                    return Opacity(
                      opacity: isAnimating ? 0.0 : 1.0,
                      child: TileWidget(
                        key: _tileKeys['$r,$c'],
                        value: board.cells[r][c],
                        isSelected: gameState.selectedRow == r &&
                            gameState.selectedCol == c,
                        isHinted: hintNotifier.isHintTile(r, c),
                        isWon: isWon,
                        onTap: () => ref
                            .read(gameStateProvider.notifier)
                            .selectTile(r, c),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: SymmetryAxisOverlay(
              type: gameState.targetSymmetry,
              achieved: isWon,
              boardSize: boardSize,
            ),
          ),
        ),
        // 스왑 고스트 타일 오버레이
        if (swp != null)
          AnimatedBuilder(
            animation: swp.controller,
            builder: (ctx, _) {
              // 0→1 진행: 타일1은 pos1→pos2, 타일2는 pos2→pos1
              final t = Curves.easeInOut.transform(swp.controller.value);
              // 약간의 arc 효과를 위해 y축에 sin 곡선 추가
              final arc = sin(swp.controller.value * pi) * -12.0;

              final ghostOffset1 = Offset.lerp(swp.startPos1, swp.startPos2, t)!
                  + Offset(0, arc);
              final ghostOffset2 = Offset.lerp(swp.startPos2, swp.startPos1, t)!
                  + Offset(0, arc);

              final val1 = board.cells[swp.r2][swp.c2]; // 스왑 후 값 (이미 교환됨)
              final val2 = board.cells[swp.r1][swp.c1];

              return Stack(
                children: [
                  Positioned(
                    left: ghostOffset1.dx,
                    top: ghostOffset1.dy,
                    child: _buildGhostTile(val1, isWon),
                  ),
                  Positioned(
                    left: ghostOffset2.dx,
                    top: ghostOffset2.dy,
                    child: _buildGhostTile(val2, isWon),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

