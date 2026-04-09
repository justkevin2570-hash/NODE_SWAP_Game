import 'board_model.dart';

class LevelConfig {
  final int episode;
  final int level; // 1~10
  final SymmetryType symmetryType;
  final int shuffleSteps;
  final int maxMoves;
  final int hintCount;
  final int timeLimitSecs;
  final int seed; // 퍼즐 고정용 시드 (같은 시드 = 같은 퍼즐)

  const LevelConfig({
    required this.episode,
    required this.level,
    required this.symmetryType,
    required this.shuffleSteps,
    required this.maxMoves,
    required this.hintCount,
    required this.timeLimitSecs,
    required this.seed,
  });

  bool get isMidBoss => level == 5;
  bool get isFinalBoss => level == 10;
  String get levelId => 'ep${episode}_lv$level';

  String get symmetryLabel {
    switch (symmetryType) {
      case SymmetryType.horizontal:
        return '좌우대칭';
      case SymmetryType.vertical:
        return '상하대칭';
      case SymmetryType.pointSymmetry:
        return '원점대칭';
    }
  }
}

class EpisodeConfig {
  final int episode;
  final List<LevelConfig> levels; // 항상 10개

  const EpisodeConfig({required this.episode, required this.levels});

  String get title => 'Episode $episode';

  SymmetryType get primarySymmetry => levels.first.symmetryType;

  String get symmetryLabel => levels.first.symmetryLabel;

  int totalStars(Map<String, int> starMap) {
    return levels.fold(0, (sum, lv) => sum + (starMap[lv.levelId] ?? 0));
  }
}
