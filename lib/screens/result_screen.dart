import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/level_config.dart';
import '../providers/progress_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final GameState gameState;
  final LevelConfig levelConfig;

  const ResultScreen({
    super.key,
    required this.gameState,
    required this.levelConfig,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saveProgress();
  }

  void _saveProgress() {
    if (_saved) return;
    _saved = true;
    final gs = widget.gameState;
    if (gs.phase == GamePhase.won) {
      ref.read(progressProvider.notifier).saveResult(
            ep: widget.levelConfig.episode,
            lv: widget.levelConfig.level,
            stars: gs.starRating,
            score: gs.score,
            moves: gs.moveCount,
          );
    }
  }

  bool get _isEpisodeComplete =>
      widget.gameState.phase == GamePhase.won &&
      widget.levelConfig.level == 10;

  @override
  Widget build(BuildContext context) {
    final gameState = widget.gameState;
    final isWon = gameState.phase == GamePhase.won;
    final stars = gameState.starRating;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 에피소드 클리어 배너
                if (_isEpisodeComplete) ...[
                  _EpisodeClearBanner(episode: widget.levelConfig.episode),
                  const SizedBox(height: 16),
                ],

                // 결과 아이콘
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, val, child) =>
                      Transform.scale(scale: val, child: child),
                  child: Icon(
                    isWon
                        ? Icons.emoji_events
                        : Icons.sentiment_dissatisfied,
                    size: 80,
                    color: isWon ? Colors.amber : Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  isWon ? '대칭 달성!' : '아쉽게도 실패...',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isWon
                        ? const Color(0xFF1B5E20)
                        : Colors.grey.shade700,
                  ),
                ),

                // 레벨 정보
                Text(
                  'Episode ${widget.levelConfig.episode} · Level ${widget.levelConfig.level}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),

                // 승리 상세
                if (isWon) ...[
                  Text(
                    '소요 시간: ${_formatTime(gameState.timeTaken)}',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  // 별점
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: i < stars ? 1.0 : 0.0),
                        duration: Duration(milliseconds: 400 + i * 200),
                        curve: Curves.elasticOut,
                        builder: (_, val, child) =>
                            Transform.scale(scale: val, child: child),
                        child: Icon(
                          i < stars ? Icons.star : Icons.star_border,
                          color: i < stars
                              ? Colors.amber
                              : Colors.grey.shade300,
                          size: 48,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['', '아쉽네요', '잘했어요!', '완벽해요!'][stars],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  _ScoreBreakdown(gameState: gameState),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '${gameState.moveCount} / ${gameState.maxMoves} 이동 사용',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gameState.timeRemaining == 0 ? '⏱ 시간 초과!' : '이동 횟수 초과!',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _LoseStats(gameState: gameState),
                  const SizedBox(height: 20),
                ],

                // ── 버튼들 ──
                // 다시 하기
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, 'retry'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3949AB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),

                // 다음 레벨 / 에피소드 클리어 후 다음
                if (isWon) ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'next'),
                    icon: Icon(
                      _isEpisodeComplete
                          ? Icons.celebration
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _isEpisodeComplete ? '다음 에피소드' : '다음 레벨',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: const Color(0xFF1A237E),
                      minimumSize: const Size(220, 48),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 레벨 선택으로
                TextButton(
                  onPressed: () => Navigator.pop(context, 'levels'),
                  child: const Text('레벨 선택으로'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '$s초';
  }
}

// ── 에피소드 클리어 배너 ───────────────────────────────────────
class _EpisodeClearBanner extends StatelessWidget {
  final int episode;

  const _EpisodeClearBanner({required this.episode});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (_, val, child) => Transform.scale(scale: val, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6F00), Color(0xFFFFCA28)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          '🎉 Episode $episode 클리어!',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── 승리 점수 내역 ────────────────────────────────────────────
class _ScoreBreakdown extends StatelessWidget {
  final GameState gameState;

  const _ScoreBreakdown({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final movesLeft = gameState.maxMoves - gameState.moveCount;
    final moveBonus = movesLeft * 50;
    final baseScore = gameState.score - moveBonus;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '점수 내역',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _RollupRow(label: '스왑 점수', value: baseScore, delay: 200),
          _RollupRow(label: '이동 효율 보너스', value: moveBonus, delay: 400),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1),
          ),
          _RollupRow(
            label: '총점',
            value: gameState.score,
            delay: 600,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _RollupRow extends StatelessWidget {
  final String label;
  final int value;
  final int delay;
  final bool highlight;

  const _RollupRow({
    required this.label,
    required this.value,
    required this.delay,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: highlight ? 16 : 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight
                  ? const Color(0xFF1A237E)
                  : Colors.grey.shade700,
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: Duration(milliseconds: 600 + delay),
            curve: Curves.easeOut,
            builder: (context2, val, child2) => Text(
              _fmt(val),
              style: TextStyle(
                fontSize: highlight ? 18 : 14,
                fontWeight: FontWeight.bold,
                color: highlight
                    ? const Color(0xFF3949AB)
                    : Colors.grey.shade800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) {
      return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return '$n';
  }
}

// ── 패배 통계 ─────────────────────────────────────────────────
class _LoseStats extends StatelessWidget {
  final GameState gameState;

  const _LoseStats({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: _StatChip(
        label: '획득 점수',
        value: '${gameState.score}',
        icon: Icons.star_outline,
        color: Colors.amber,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}
