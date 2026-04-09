class LevelResult {
  final int stars; // 1~3
  final int bestScore;
  final int bestMoves;

  const LevelResult({
    required this.stars,
    required this.bestScore,
    required this.bestMoves,
  });

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'bestScore': bestScore,
        'bestMoves': bestMoves,
      };

  factory LevelResult.fromJson(Map<String, dynamic> json) => LevelResult(
        stars: json['stars'] as int,
        bestScore: json['bestScore'] as int,
        bestMoves: json['bestMoves'] as int,
      );
}

class PlayerProgress {
  /// 키: "ep{N}_lv{N}", 값: LevelResult
  final Map<String, LevelResult> results;

  const PlayerProgress({required this.results});

  factory PlayerProgress.initial() {
    // 에피소드1 레벨1만 잠금 해제 (결과 없음 = 클리어 안 됨 = 잠금 해제됨)
    return const PlayerProgress(results: {});
  }

  // ── 잠금 해제 여부 ──────────────────────────────────────────
  bool isUnlocked(int ep, int lv) {
    if (ep == 1 && lv == 1) return true;
    // 같은 에피소드 이전 레벨 클리어 여부
    if (lv > 1) return isCompleted(ep, lv - 1);
    // 레벨 1인 경우: 이전 에피소드 마지막 레벨 클리어 여부
    return isCompleted(ep - 1, 10);
  }

  // ── 클리어 여부 ─────────────────────────────────────────────
  bool isCompleted(int ep, int lv) {
    final key = 'ep${ep}_lv$lv';
    return results.containsKey(key);
  }

  // ── 별점 (0 = 미클리어) ─────────────────────────────────────
  int getStars(int ep, int lv) {
    return results['ep${ep}_lv$lv']?.stars ?? 0;
  }

  // ── 전체 별 수 ──────────────────────────────────────────────
  int get totalStars => results.values.fold(0, (s, r) => s + r.stars);

  // ── 클리어한 에피소드 중 가장 높은 번호 ──────────────────────
  int get highestUnlockedEpisode {
    int maxEp = 1;
    for (final key in results.keys) {
      final match = RegExp(r'^ep(\d+)_lv(\d+)$').firstMatch(key);
      if (match != null) {
        final ep = int.parse(match.group(1)!);
        if (ep > maxEp) maxEp = ep;
      }
    }
    return maxEp;
  }

  // ── 결과 저장 (최고기록만 갱신) ─────────────────────────────
  PlayerProgress withResult({
    required int ep,
    required int lv,
    required int stars,
    required int score,
    required int moves,
  }) {
    final key = 'ep${ep}_lv$lv';
    final existing = results[key];
    final newResult = LevelResult(
      stars: (existing == null || stars > existing.stars)
          ? stars
          : existing.stars,
      bestScore: (existing == null || score > existing.bestScore)
          ? score
          : existing.bestScore,
      bestMoves: (existing == null || moves < existing.bestMoves)
          ? moves
          : existing.bestMoves,
    );
    return PlayerProgress(results: {...results, key: newResult});
  }

  // ── 직렬화 ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return results.map((k, v) => MapEntry(k, v.toJson()));
  }

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    return PlayerProgress(
      results: json.map(
        (k, v) => MapEntry(k, LevelResult.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}
