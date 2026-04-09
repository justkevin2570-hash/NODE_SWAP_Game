import '../models/board_model.dart';
import '../models/level_config.dart';
import 'puzzles/episode_01.dart';
import 'puzzles/episode_02.dart';
import 'puzzles/episode_03.dart';
import 'puzzles/episode_04.dart';
import 'puzzles/episode_05.dart';
import 'puzzles/episode_06.dart';
import 'puzzles/episode_07.dart';
import 'puzzles/episode_08.dart';
import 'puzzles/episode_09.dart';
import 'puzzles/episode_10.dart';
import 'puzzles/episode_11.dart';
import 'puzzles/episode_12.dart';
import 'puzzles/episode_13.dart';
import 'puzzles/episode_14.dart';
import 'puzzles/episode_15.dart';

// ── 에피소드별 시드 테이블 (1-based index, ep1=index0) ──────────
const _episodeSeeds = [
  episode01Seeds, // ep 1
  episode02Seeds, // ep 2
  episode03Seeds, // ep 3
  episode04Seeds, // ep 4
  episode05Seeds, // ep 5
  episode06Seeds, // ep 6
  episode07Seeds, // ep 7
  episode08Seeds, // ep 8
  episode09Seeds, // ep 9
  episode10Seeds, // ep 10
  episode11Seeds, // ep 11
  episode12Seeds, // ep 12
  episode13Seeds, // ep 13
  episode14Seeds, // ep 14
  episode15Seeds, // ep 15
];

// ── 레벨 포지션(0-based)별 ep1 기준 base 파라미터 ───────────────
const _baseShuffle = [3, 3, 4, 4, 5, 5, 5, 6, 6, 7];
const _baseMoves   = [10, 9, 9, 8, 7, 7, 7, 6, 6, 5];
const _baseHints   = [3,  3, 3, 2, 2, 2, 2, 1, 1, 1];
const _baseTime    = [150, 140, 130, 120, 100, 100, 90, 90, 80, 60];

/// 에피소드 16+ 에서 레벨별 대칭 타입 순환
SymmetryType _mixedSymmetry(int levelPos) {
  const types = [
    SymmetryType.horizontal,
    SymmetryType.vertical,
    SymmetryType.pointSymmetry,
  ];
  return types[levelPos % 3];
}

/// 에피소드 E(1-based), 레벨 포지션 pos(0-based) → LevelConfig
LevelConfig _makeLevel({
  required int episode,
  required int levelPos,
  required SymmetryType symmetry,
  required int seed,
}) {
  final ep0 = episode - 1;

  final shuffle = (_baseShuffle[levelPos] + (ep0 * 0.5)).round().clamp(3, 20);
  final moves   = (_baseMoves[levelPos]   - (ep0 * 0.5)).round().clamp(3, 20);
  final hints   = _baseHints[levelPos];
  final time    = (_baseTime[levelPos]    - (ep0 * 5)).clamp(30, 300);

  return LevelConfig(
    episode: episode,
    level: levelPos + 1,
    symmetryType: symmetry,
    shuffleSteps: shuffle,
    maxMoves: moves,
    hintCount: hints,
    timeLimitSecs: time,
    seed: seed,
  );
}

/// 에피소드 번호로 EpisodeConfig 반환 (무한 생성 지원)
EpisodeConfig buildEpisode(int episode) {
  // ep 1~15: 미리 정의된 시드 사용
  // ep 16+: 공식으로 시드 자동 계산
  List<int> seeds;
  if (episode <= 15) {
    seeds = _episodeSeeds[episode - 1];
  } else {
    seeds = List.generate(10, (pos) => episode * 10000 + (pos + 1));
  }

  SymmetryType Function(int pos) symmetryFor;
  if (episode <= 5) {
    symmetryFor = (_) => SymmetryType.horizontal;
  } else if (episode <= 10) {
    symmetryFor = (_) => SymmetryType.vertical;
  } else if (episode <= 15) {
    symmetryFor = (_) => SymmetryType.pointSymmetry;
  } else {
    symmetryFor = _mixedSymmetry;
  }

  return EpisodeConfig(
    episode: episode,
    levels: List.generate(
      10,
      (pos) => _makeLevel(
        episode: episode,
        levelPos: pos,
        symmetry: symmetryFor(pos),
        seed: seeds[pos],
      ),
    ),
  );
}

class LevelData {
  LevelData._();

  static EpisodeConfig getEpisode(int episode) => buildEpisode(episode);

  static LevelConfig getNextLevel(LevelConfig current) {
    if (current.level < 10) {
      return getEpisode(current.episode).levels[current.level];
    } else {
      return getEpisode(current.episode + 1).levels[0];
    }
  }

  static LevelConfig? fromId(String id) {
    final match = RegExp(r'^ep(\d+)_lv(\d+)$').firstMatch(id);
    if (match == null) return null;
    final ep = int.parse(match.group(1)!);
    final lv = int.parse(match.group(2)!);
    if (ep < 1 || lv < 1 || lv > 10) return null;
    return getEpisode(ep).levels[lv - 1];
  }
}
