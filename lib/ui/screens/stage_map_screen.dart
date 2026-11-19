import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../core/palette.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../game/logic/rules.dart';
import '../widgets/bubbly.dart';
import '../widgets/layout.dart';
import '../widgets/pastel_background.dart';
import 'game_screen.dart';
import 'sheets.dart';

/// 클래식 판 크기별 1~100탄 지도. 깬 탄은 별, 다음 탄은 반짝임, 나머지는 잠김.
class StageMapScreen extends ConsumerStatefulWidget {
  const StageMapScreen({super.key, required this.boardSize});

  final BoardSize boardSize;

  @override
  ConsumerState<StageMapScreen> createState() => _StageMapScreenState();
}

class _StageMapScreenState extends ConsumerState<StageMapScreen> {
  static const _columns = 5;
  static const _spacing = 10.0;
  final _scroll = ScrollController();
  bool _scrolled = false;

  (Color, Color) get _colors => boardSizeColors(widget.boardSize);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _play(int stage) async {
    await Navigator.of(context).push(softRoute(GameScreen(
      mode: GameMode.classic,
      boardSize: widget.boardSize,
      stage: stage,
    )));
    if (mounted) ref.read(audioProvider).setMusic(Music.menu, fade: const Duration(milliseconds: 900));
  }

  /// 처음 열 때 지금 할 탄이 보이도록 스크롤한다.
  void _scrollToNext(double cellSize, int next) {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final row = (next - 1) ~/ _columns;
      final target = (row - 1).clamp(0, 1000) * (cellSize + 22 + _spacing);
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(stageProgressProvider);
    final d = widget.boardSize;
    final (light, deep) = _colors;
    final next = progress.nextStage(d);
    final cleared = progress.clearedCount(d);
    return Scaffold(
      body: PastelBackground(
        tint: light,
        child: SafeArea(
          child: PhoneColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).pop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('클래식 | ${d.label}', style: TextStyles.title.copyWith(fontSize: 24)),
                            Text('$cleared / ${Rules.stageCount}탄 클리어', style: TextStyles.caption),
                          ],
                        ),
                      ),
                      Pill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Palette.butterDeep, size: 22),
                            const SizedBox(width: 4),
                            Text('${progress.totalStars(d)} / ${Rules.stageCount * 3}',
                                style: TextStyles.number.copyWith(fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final cell = (c.maxWidth - _spacing * (_columns - 1)) / _columns;
                      _scrollToNext(cell, next);
                      return GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.only(bottom: 24, top: 4),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columns,
                          mainAxisSpacing: _spacing,
                          crossAxisSpacing: _spacing,
                          childAspectRatio: cell / (cell + 22),
                        ),
                        itemCount: Rules.stageCount,
                        itemBuilder: (context, i) {
                          final stage = i + 1;
                          return StageTile(
                            stage: stage,
                            stars: progress.starsOf(d, stage),
                            unlocked: progress.isUnlocked(d, stage),
                            current: stage == next && progress.starsOf(d, stage) == 0,
                            light: light,
                            deep: deep,
                            onTap: () => _play(stage),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 스테이지 한 칸: 게임 타일 모양 버튼 + 아래 별 3개.
class StageTile extends StatefulWidget {
  const StageTile({
    super.key,
    required this.stage,
    required this.stars,
    required this.unlocked,
    required this.current,
    required this.light,
    required this.deep,
    required this.onTap,
  });

  final int stage;
  final int stars;
  final bool unlocked;
  final bool current;
  final Color light;
  final Color deep;
  final VoidCallback onTap;

  @override
  State<StageTile> createState() => _StageTileState();
}

class _StageTileState extends State<StageTile> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.current) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StageTile old) {
    super.didUpdateWidget(old);
    if (widget.current && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.current && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleared = widget.stars > 0;
    final unlocked = widget.unlocked;
    return GestureDetector(
      onTapDown: unlocked ? (_) => setState(() => _down = true) : null,
      onTapCancel: unlocked ? () => setState(() => _down = false) : null,
      onTapUp: unlocked
          ? (_) {
              setState(() => _down = false);
              widget.onTap();
            }
          : null,
      child: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => AnimatedScale(
                scale: _down ? 0.92 : 1 + _pulse.value * 0.06,
                duration: const Duration(milliseconds: 120),
                child: child,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: cleared || widget.current
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color.lerp(widget.light, Colors.white, 0.3)!, widget.light],
                          )
                        : null,
                    color: cleared || widget.current ? null : Colors.white.withValues(alpha: unlocked ? 0.9 : 0.5),
                    border: Border.all(
                      color: widget.current ? Palette.butterDeep : Colors.white,
                      width: widget.current ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.current ? Palette.butterDeep : widget.deep).withValues(alpha: unlocked ? 0.3 : 0.08),
                        blurRadius: widget.current ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: unlocked
                      ? Text('${widget.stage}', style: TextStyles.number.copyWith(fontSize: 22, color: Palette.ink))
                      : Icon(Icons.lock_rounded, color: Palette.inkFaint.withValues(alpha: 0.9), size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: i < widget.stars ? Palette.butterDeep : Palette.inkFaint.withValues(alpha: unlocked ? 0.6 : 0.25),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
