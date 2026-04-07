import 'dart:math';

enum SymmetryType { horizontal, vertical, pointSymmetry }

class BoardModel {
  final List<List<int>> cells;

  const BoardModel(this.cells);

  factory BoardModel.empty() {
    return BoardModel(List.generate(5, (_) => List.filled(5, 0)));
  }

  BoardModel copyWith({List<List<int>>? cells}) {
    return BoardModel(
      cells ?? this.cells.map((row) => List<int>.from(row)).toList(),
    );
  }

  // ── 대칭 체크 ──────────────────────────────────────────────
  bool checkSymmetry(SymmetryType type) {
    switch (type) {
      case SymmetryType.horizontal: // 좌우 대칭
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 2; c++) {
            if (cells[r][c] != cells[r][4 - c]) return false;
          }
        }
        return true;

      case SymmetryType.vertical: // 상하 대칭
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 5; c++) {
            if (cells[r][c] != cells[4 - r][c]) return false;
          }
        }
        return true;

      case SymmetryType.pointSymmetry: // 점대칭 (180도)
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (cells[r][c] != cells[4 - r][4 - c]) return false;
          }
        }
        return true;
    }
  }

  // 비대칭 쌍의 수 (힌트 계산용)
  int asymmetryCount(SymmetryType type) {
    int count = 0;
    switch (type) {
      case SymmetryType.horizontal:
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 2; c++) {
            if (cells[r][c] != cells[r][4 - c]) count++;
          }
        }
      case SymmetryType.vertical:
        for (int r = 0; r < 2; r++) {
          for (int c = 0; c < 5; c++) {
            if (cells[r][c] != cells[4 - r][c]) count++;
          }
        }
      case SymmetryType.pointSymmetry:
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (cells[r][c] != cells[4 - r][4 - c]) count++;
          }
        }
    }
    return count;
  }

  // ── Swap ──────────────────────────────────────────────────
  bool isAdjacent(int r1, int c1, int r2, int c2) {
    final rowDiff = (r1 - r2).abs();
    final colDiff = (c1 - c2).abs();
    return (rowDiff == 1 && colDiff == 0) || (rowDiff == 0 && colDiff == 1);
  }

  BoardModel swap(int r1, int c1, int r2, int c2) {
    final newCells = cells.map((row) => List<int>.from(row)).toList();
    final temp = newCells[r1][c1];
    newCells[r1][c1] = newCells[r2][c2];
    newCells[r2][c2] = temp;
    return BoardModel(newCells);
  }

  // 모든 인접 swap 쌍 반환 (힌트·퍼즐 생성용)
  List<(int, int, int, int)> adjacentSwaps() {
    final result = <(int, int, int, int)>[];
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        if (c + 1 < 5) result.add((r, c, r, c + 1)); // 우측
        if (r + 1 < 5) result.add((r, c, r + 1, c)); // 아래
      }
    }
    return result;
  }

  // ── 90도 시계방향 회전 ──────────────────────────────────────
  // newBoard[c][4-r] = board[r][c]
  BoardModel rotate90CW() {
    final newCells = List.generate(5, (_) => List.filled(5, 0));
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        newCells[c][4 - r] = cells[r][c];
      }
    }
    return BoardModel(newCells);
  }

  // ── 풀 수 있는 퍼즐 생성 (역방향 생성) ──────────────────────
  static BoardModel generateSolvable(
    SymmetryType type, {
    int shuffleSteps = 10,
    int retryLimit = 10,
    int retryCount = 0,
  }) {
    // Step 1: 대칭 보드 생성
    BoardModel board = _generateSymmetric(type);

    // Step 2: swap shuffleSteps회 + 회전 1회를 랜덤 위치에 섞어서 적용
    // (회전이 포함되면 swap만으로는 풀기 어렵고, 회전을 활용해야 효율적으로 풀 수 있음)
    final random = Random();
    final totalOps = shuffleSteps + 1; // swap N회 + 회전 1회
    final rotationAt = random.nextInt(totalOps); // 회전을 넣을 위치
    (int, int, int, int)? lastSwap;

    for (int step = 0; step < totalOps; step++) {
      if (step == rotationAt) {
        board = board.rotate90CW();
        lastSwap = null; // 회전 후 직전 swap 초기화
      } else {
        final swaps = board.adjacentSwaps();
        final candidates = lastSwap == null
            ? swaps
            : swaps.where((s) => s != lastSwap).toList();
        final s = candidates[random.nextInt(candidates.length)];
        board = board.swap(s.$1, s.$2, s.$3, s.$4);
        lastSwap = s;
      }
    }

    // Step 3: 여전히 대칭이면 재시도
    if (board.checkSymmetry(type)) {
      if (retryCount >= retryLimit) return board;
      return generateSolvable(
        type,
        shuffleSteps: shuffleSteps,
        retryLimit: retryLimit,
        retryCount: retryCount + 1,
      );
    }

    return board;
  }

  static BoardModel _generateSymmetric(SymmetryType type) {
    final random = Random();
    final cells = List.generate(5, (_) => List.filled(5, 0));

    switch (type) {
      case SymmetryType.horizontal:
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 3; c++) {
            final val = random.nextInt(2);
            cells[r][c] = val;
            cells[r][4 - c] = val;
          }
        }
      case SymmetryType.vertical:
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 5; c++) {
            final val = random.nextInt(2);
            cells[r][c] = val;
            cells[4 - r][c] = val;
          }
        }
      case SymmetryType.pointSymmetry:
        for (int r = 0; r < 5; r++) {
          for (int c = 0; c < 5; c++) {
            if (cells[4 - r][4 - c] != 0 || (r == 4 - r && c == 4 - c)) {
              continue;
            }
            final val = random.nextInt(2);
            cells[r][c] = val;
            cells[4 - r][4 - c] = val;
          }
        }
        // 중앙(2,2)은 독립적으로 랜덤
        cells[2][2] = random.nextInt(2);
    }

    return BoardModel(cells);
  }
}
