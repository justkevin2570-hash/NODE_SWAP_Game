import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/level_data.dart';
import '../models/board_model.dart';
import '../models/level_config.dart';
import '../providers/progress_provider.dart';
import 'level_select_screen.dart';

class EpisodeSelectScreen extends ConsumerWidget {
  const EpisodeSelectScreen({super.key});

  // 표시할 에피소드 수: 클리어한 가장 높은 에피소드 + 1 (다음 에피소드까지)
  // 최소 3개 항상 표시
  int _visibleEpisodeCount(int highestUnlocked) {
    return (highestUnlocked + 1).clamp(3, 999);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final highestUnlocked = progress.highestUnlockedEpisode;
    final count = _visibleEpisodeCount(highestUnlocked);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        title: const Text(
          '에피소드 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${progress.totalStars}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        itemBuilder: (ctx, index) {
          final episodeNum = index + 1;
          final episode = LevelData.getEpisode(episodeNum);
          final isUnlocked = progress.isUnlocked(episodeNum, 1);
          final clearedLevels = List.generate(10, (i) {
            return progress.isCompleted(episodeNum, i + 1) ? 1 : 0;
          }).fold(0, (a, b) => a + b);
          final totalEpStars = List.generate(10, (i) {
            return progress.getStars(episodeNum, i + 1);
          }).fold(0, (a, b) => a + b);

          return _EpisodeCard(
            episode: episode,
            isUnlocked: isUnlocked,
            clearedLevels: clearedLevels,
            totalStars: totalEpStars,
            onTap: isUnlocked
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LevelSelectScreen(episode: episode),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final EpisodeConfig episode;
  final bool isUnlocked;
  final int clearedLevels;
  final int totalStars;
  final VoidCallback? onTap;

  const _EpisodeCard({
    required this.episode,
    required this.isUnlocked,
    required this.clearedLevels,
    required this.totalStars,
    required this.onTap,
  });

  Color get _typeColor {
    switch (episode.primarySymmetry) {
      case SymmetryType.horizontal:
        return const Color(0xFF3949AB);
      case SymmetryType.vertical:
        return const Color(0xFF00897B);
      case SymmetryType.pointSymmetry:
        return const Color(0xFF8E24AA);
    }
  }

  IconData get _typeIcon {
    switch (episode.primarySymmetry) {
      case SymmetryType.horizontal:
        return Icons.swap_horiz;
      case SymmetryType.vertical:
        return Icons.swap_vert;
      case SymmetryType.pointSymmetry:
        return Icons.all_out;
    }
  }

  String get _typeLabel {
    // 에피소드 16+는 혼합
    if (episode.levels.map((l) => l.symmetryType).toSet().length > 1) {
      return '혼합 대칭';
    }
    return episode.symmetryLabel;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isUnlocked ? 2 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? _typeColor.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isUnlocked ? _typeIcon : Icons.lock,
                    color: isUnlocked ? _typeColor : Colors.grey.shade400,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? const Color(0xFF1A237E)
                              : Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnlocked ? _typeColor : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 진행도
                      if (isUnlocked) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: clearedLevels / 10,
                            backgroundColor: Colors.grey.shade200,
                            color: _typeColor,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$clearedLevels / 10 클리어',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ] else
                        Text(
                          '잠금',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                ),

                // 별
                if (isUnlocked) ...[
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      Text(
                        '$totalStars/30',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
