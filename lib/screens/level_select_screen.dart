import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level_config.dart';
import '../providers/progress_provider.dart';
import 'game_screen.dart';

class LevelSelectScreen extends ConsumerWidget {
  final EpisodeConfig episode;

  const LevelSelectScreen({super.key, required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        title: Text(
          episode.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                episode.symmetryLabel,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: 10,
          itemBuilder: (ctx, index) {
            final levelConfig = episode.levels[index];
            final isUnlocked = progress.isUnlocked(
              episode.episode,
              levelConfig.level,
            );
            final stars = progress.getStars(episode.episode, levelConfig.level);

            return _LevelCard(
              config: levelConfig,
              isUnlocked: isUnlocked,
              stars: stars,
              onTap: isUnlocked
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameScreen(config: levelConfig),
                        ),
                      );
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final LevelConfig config;
  final bool isUnlocked;
  final int stars; // 0~3
  final VoidCallback? onTap;

  const _LevelCard({
    required this.config,
    required this.isUnlocked,
    required this.stars,
    required this.onTap,
  });

  Color get _cardColor {
    if (!isUnlocked) return Colors.grey.shade100;
    if (config.isFinalBoss) return const Color(0xFF4A148C);
    if (config.isMidBoss) return const Color(0xFF1565C0);
    return const Color(0xFF3949AB);
  }

  String get _badgeText {
    if (config.isFinalBoss) return '👑';
    if (config.isMidBoss) return '⚔️';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isUnlocked ? _cardColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: _cardColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // 잠금 아이콘
              if (!isUnlocked)
                const Center(
                  child: Icon(Icons.lock, color: Colors.grey, size: 32),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 레벨 번호 + 배지
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${config.level}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_badgeText.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              _badgeText,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ],
                      ),
                      // 별점
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Icon(
                            i < stars ? Icons.star : Icons.star_border,
                            color: i < stars
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.4),
                            size: 18,
                          );
                        }),
                      ),
                    ],
                  ),
                ),

              // 레벨 번호 라벨 (잠금 상태)
              if (!isUnlocked)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Level ${config.level}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
